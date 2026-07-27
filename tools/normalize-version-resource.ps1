# Ahk2Exe 版本资源的确定性规范化。
# 上游 VersionRes.Save() 不会初始化节点之间的四字节对齐填充，可能把进程内存残值
# 写入最终 EXE。本脚本按 VERSIONINFO 结构解析所有语言资源，只清零这些填充字节，
# 再通过 Windows 资源 API 原位更新资源，从而消除与宿主进程和内存布局有关的差异。

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ExecutablePath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$fullExecutablePath = [System.IO.Path]::GetFullPath($ExecutablePath)
if (-not (Test-Path -LiteralPath $fullExecutablePath -PathType Leaf)) {
    throw "Compiled executable does not exist: $fullExecutablePath"
}

if (-not ('ReleaseVersionResourceNormalizer' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Runtime.InteropServices;

public static class ReleaseVersionResourceNormalizer
{
    private const uint LoadLibraryAsDataFile = 0x00000002;
    private static readonly IntPtr VersionResourceType = new IntPtr(16);
    private static readonly IntPtr VersionResourceName = new IntPtr(1);

    private delegate bool EnumResourceLanguagesCallback(
        IntPtr module, IntPtr type, IntPtr name, ushort language,
        IntPtr parameter);

    private sealed class ResourceUpdate
    {
        public ushort Language;
        public byte[] Data;
    }

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode,
        SetLastError = true)]
    private static extern IntPtr LoadLibraryExW(
        string fileName, IntPtr file, uint flags);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool FreeLibrary(IntPtr module);

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode,
        SetLastError = true)]
    private static extern bool EnumResourceLanguagesW(
        IntPtr module, IntPtr type, IntPtr name,
        EnumResourceLanguagesCallback callback, IntPtr parameter);

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode,
        SetLastError = true)]
    private static extern IntPtr FindResourceExW(
        IntPtr module, IntPtr type, IntPtr name, ushort language);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern uint SizeofResource(IntPtr module, IntPtr resource);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern IntPtr LoadResource(IntPtr module, IntPtr resource);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern IntPtr LockResource(IntPtr resourceData);

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode,
        SetLastError = true)]
    private static extern IntPtr BeginUpdateResourceW(
        string fileName, bool deleteExistingResources);

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode,
        SetLastError = true)]
    private static extern bool UpdateResourceW(
        IntPtr update, IntPtr type, IntPtr name, ushort language,
        IntPtr data, uint size);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool EndUpdateResourceW(
        IntPtr update, bool discard);

    public static void Normalize(string executablePath)
    {
        List<ResourceUpdate> resources = ReadVersionResources(executablePath);
        IntPtr update = BeginUpdateResourceW(executablePath, false);
        if (update == IntPtr.Zero)
            ThrowLastWin32("Unable to open the executable for resource update");

        bool committed = false;
        try
        {
            foreach (ResourceUpdate resource in resources)
            {
                GCHandle pinned = GCHandle.Alloc(resource.Data,
                    GCHandleType.Pinned);
                try
                {
                    if (!UpdateResourceW(update, VersionResourceType,
                            VersionResourceName, resource.Language,
                            pinned.AddrOfPinnedObject(),
                            checked((uint)resource.Data.Length)))
                        ThrowLastWin32("Unable to update the version resource");
                }
                finally
                {
                    pinned.Free();
                }
            }

            if (!EndUpdateResourceW(update, false))
                ThrowLastWin32("Unable to commit the version resource");
            committed = true;
        }
        finally
        {
            if (!committed)
                EndUpdateResourceW(update, true);
        }
    }

    private static List<ResourceUpdate> ReadVersionResources(
        string executablePath)
    {
        IntPtr module = LoadLibraryExW(executablePath, IntPtr.Zero,
            LoadLibraryAsDataFile);
        if (module == IntPtr.Zero)
            ThrowLastWin32("Unable to load the compiled executable resources");

        try
        {
            List<ushort> languages = new List<ushort>();
            EnumResourceLanguagesCallback callback = delegate(
                IntPtr ignoredModule, IntPtr ignoredType, IntPtr ignoredName,
                ushort language, IntPtr ignoredParameter)
            {
                languages.Add(language);
                return true;
            };
            if (!EnumResourceLanguagesW(module, VersionResourceType,
                    VersionResourceName, callback, IntPtr.Zero))
                ThrowLastWin32("Unable to enumerate version resource languages");
            if (languages.Count == 0)
                throw new InvalidOperationException(
                    "The compiled executable has no version resource.");

            languages.Sort();
            List<ResourceUpdate> resources = new List<ResourceUpdate>();
            foreach (ushort language in languages)
            {
                IntPtr resource = FindResourceExW(module,
                    VersionResourceType, VersionResourceName, language);
                if (resource == IntPtr.Zero)
                    ThrowLastWin32("Unable to find the version resource");
                uint size = SizeofResource(module, resource);
                IntPtr loaded = LoadResource(module, resource);
                IntPtr address = loaded == IntPtr.Zero
                    ? IntPtr.Zero : LockResource(loaded);
                if (size == 0 || address == IntPtr.Zero)
                    ThrowLastWin32("Unable to read the version resource");

                byte[] data = new byte[checked((int)size)];
                Marshal.Copy(address, data, 0, data.Length);
                int rootLength = NormalizeNode(data, 0, data.Length);
                Clear(data, rootLength, data.Length);
                resources.Add(new ResourceUpdate {
                    Language = language,
                    Data = data
                });
            }
            GC.KeepAlive(callback);
            return resources;
        }
        finally
        {
            FreeLibrary(module);
        }
    }

    private static int NormalizeNode(byte[] data, int offset, int limit)
    {
        if (offset < 0 || limit - offset < 6)
            throw new InvalidOperationException(
                "The VERSIONINFO node header is truncated.");

        int length = ReadUInt16(data, offset);
        int valueLength = ReadUInt16(data, offset + 2);
        int type = ReadUInt16(data, offset + 4);
        if (length < 6 || length > limit - offset || (type != 0 && type != 1))
            throw new InvalidOperationException(
                "The VERSIONINFO node header is invalid.");
        int nodeEnd = checked(offset + length);

        int cursor = offset + 6;
        while (cursor + 1 < nodeEnd &&
            (data[cursor] != 0 || data[cursor + 1] != 0))
            cursor += 2;
        if (cursor + 1 >= nodeEnd)
            throw new InvalidOperationException(
                "The VERSIONINFO node key is not terminated.");

        int valueOffset = Align4(checked(cursor + 2));
        if (valueOffset > nodeEnd)
            throw new InvalidOperationException(
                "The VERSIONINFO key padding exceeds its node.");
        Clear(data, cursor + 2, valueOffset);

        int valueSize = checked(valueLength * (type == 1 ? 2 : 1));
        int valueEnd = checked(valueOffset + valueSize);
        if (valueEnd > nodeEnd)
            throw new InvalidOperationException(
                "The VERSIONINFO value exceeds its node.");
        int childOffset = Align4(valueEnd);
        if (childOffset > nodeEnd)
            throw new InvalidOperationException(
                "The VERSIONINFO value padding exceeds its node.");
        Clear(data, valueEnd, childOffset);

        while (childOffset < nodeEnd)
        {
            if (nodeEnd - childOffset < 2)
                throw new InvalidOperationException(
                    "The VERSIONINFO child header is truncated.");
            int childLength = ReadUInt16(data, childOffset);
            if (childLength == 0)
            {
                Clear(data, childOffset, nodeEnd);
                break;
            }
            NormalizeNode(data, childOffset, nodeEnd);
            int nextChild = Align4(checked(childOffset + childLength));
            if (nextChild > nodeEnd)
                throw new InvalidOperationException(
                    "The VERSIONINFO child padding exceeds its parent.");
            Clear(data, childOffset + childLength, nextChild);
            childOffset = nextChild;
        }
        return nodeEnd;
    }

    private static int ReadUInt16(byte[] data, int offset)
    {
        return data[offset] | (data[offset + 1] << 8);
    }

    private static int Align4(int value)
    {
        return checked((value + 3) & ~3);
    }

    private static void Clear(byte[] data, int start, int end)
    {
        if (end > start)
            Array.Clear(data, start, end - start);
    }

    private static void ThrowLastWin32(string message)
    {
        throw new Win32Exception(Marshal.GetLastWin32Error(), message);
    }
}
'@
}

[ReleaseVersionResourceNormalizer]::Normalize($fullExecutablePath)

class IniFieldCodec {
    static Encode(value) {
        value := String(value)
        byteCount := StrPut(value, "UTF-8") - 1
        if byteCount <= 0
            return ""
        encodedBuffer := Buffer(byteCount + 1, 0)
        StrPut(value, encodedBuffer, "UTF-8")
        hex := ""
        Loop byteCount
            hex .= Format("{:02X}", NumGet(encodedBuffer,
                A_Index - 1, "UChar"))
        return "<HEX>" hex
    }

    static Decode(value) {
        value := String(value)
        if SubStr(value, 1, 5) != "<HEX>"
            return value
        hex := SubStr(value, 6)
        if Mod(StrLen(hex), 2)
            || (hex != "" && !RegExMatch(hex, "i)^[0-9a-f]+$")) {
            return value
        }
        byteCount := StrLen(hex) // 2
        if byteCount == 0
            return ""
        decodedBuffer := Buffer(byteCount + 1, 0)
        Loop byteCount {
            byte := Integer("0x" SubStr(hex, A_Index * 2 - 1, 2))
            NumPut("UChar", byte, decodedBuffer, A_Index - 1)
        }
        try decodedValue := StrGet(decodedBuffer, byteCount, "UTF-8")
        catch
            return value
        return IniFieldCodec.Encode(decodedValue) == "<HEX>" StrUpper(hex)
            ? decodedValue : value
    }
}

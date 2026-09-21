public var windowsX64 = "tailwindcss-windows-x64.exe"
public var windowsArm64 = "tailwindcss-windows-arm64.exe"
public var macosX64 = "tailwindcss-macos-x64"
public var macosArm64 = "tailwindcss-macos-arm64"
public var linuxX64 = "tailwindcss-linux-x64"
public var linuxArm64 = "tailwindcss-linux-arm64"
public var linuxArm7 = "tailwindcss-linux-armv7"


public func installTailwind(option: String) {
    var request = "curl -sLO https://github.com/tailwindlabs/tailwindcss/releases/latest/download/\(option)"
    var install = "chmod +x \(option)"
    var move = "mv \(option) tailwindcss"
}

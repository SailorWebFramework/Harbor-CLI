public struct Fleet: Codable {
    public let name: String
    public let location: String
    public let version: String
}
public struct Crate: Codable {
    public let name: String
    public let location: String
    public let version: String
}
public struct DockContent: Codable {
    public let fleet: [String: Fleet]
    public let crates: [String: Crate]
}
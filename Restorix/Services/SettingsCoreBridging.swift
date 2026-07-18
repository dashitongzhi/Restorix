protocol SettingsCoreBridging: AnyObject {
    func getConfig() async throws -> AppSettings
    func commitSettings(_ draft: SettingsDraft) async throws -> AppSettings
}

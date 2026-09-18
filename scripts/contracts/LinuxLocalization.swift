#if os(Linux)
// Foundation on Linux lacks String(localized:). Core tests don't exercise UI localization.
extension String {
    init(localized value: String) { self = value }
}
#endif

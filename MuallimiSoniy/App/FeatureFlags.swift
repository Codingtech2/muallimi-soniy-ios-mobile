/// Compile-time switches for features that are built but not shown yet.
nonisolated enum FeatureFlags {
    /// The Masjidlar map: its tab, the Settings toggle and the map-data
    /// credits row. Hidden since 2026-10-26 (product decision). The code and
    /// the bundled dataset stay, so turning this back on is all it takes.
    static let mosquesMap = false
}

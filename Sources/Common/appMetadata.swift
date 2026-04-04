public let stableAeroSpaceAppId: String = "ip7e.yoke"
#if DEBUG
    public let aeroSpaceAppId: String = "ip7e.yoke.debug"
    public let aeroSpaceAppName: String = "Yoke-Debug"
#else
    public let aeroSpaceAppId: String = stableAeroSpaceAppId
    public let aeroSpaceAppName: String = "Yoke"
#endif

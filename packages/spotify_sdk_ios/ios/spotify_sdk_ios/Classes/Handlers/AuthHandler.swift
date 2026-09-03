import Flutter
import SpotifyiOS

class AuthHandler: NSObject {
    private unowned let remoteManager: RemoteManager

    init(remoteManager: RemoteManager) {
        self.remoteManager = remoteManager
        super.init()
    }

    public func connectToSpotify(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let swiftArguments = call.arguments as? [String: Any],
              let clientID = swiftArguments[SpotifySdkConstants.paramClientId] as? String,
              !clientID.isEmpty else {
            result(SpotifyErrorMapper.argumentError("Client ID is not set"))
            return
        }

        guard let url = swiftArguments[SpotifySdkConstants.paramRedirectUrl] as? String,
              !url.isEmpty else {
            result(SpotifyErrorMapper.argumentError("Redirect URL is not set"))
            return
        }

        remoteManager.connectionStatusHandler?.connectionResult = result
        let accessToken: String? = swiftArguments[SpotifySdkConstants.paramAccessToken] as? String
        let spotifyUri: String = swiftArguments[SpotifySdkConstants.paramSpotifyUri] as? String ?? ""

        do {
            try connectToSpotifyInternal(clientId: clientID, redirectURL: url, accessToken: accessToken, spotifyUri: spotifyUri, asRadio: swiftArguments[SpotifySdkConstants.paramAsRadio] as? Bool, additionalScopes: swiftArguments[SpotifySdkConstants.scope] as? String)
        }
        catch SpotifyError.redirectURLInvalid {
            result(SpotifyErrorMapper.makeError(code: "errorConnecting", message: "Redirect URL is not set or has invalid format"))
        }
        catch {
            result(SpotifyErrorMapper.makeError(code: "CouldNotFindSpotifyApp", message: "The Spotify app is not installed on the device"))
        }
    }

    public func getAccessTokenOrSwapToken(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let swiftArguments = call.arguments as? [String: Any],
              let clientID = swiftArguments[SpotifySdkConstants.paramClientId] as? String,
              let url = swiftArguments[SpotifySdkConstants.paramRedirectUrl] as? String else {
            result(SpotifyErrorMapper.argumentError("One or more arguments are missing"))
            return
        }
        remoteManager.connectionStatusHandler?.tokenResult = result
        let spotifyUri: String = swiftArguments[SpotifySdkConstants.paramSpotifyUri] as? String ?? ""

        do {
            try connectToSpotifyInternal(clientId: clientID, redirectURL: url, spotifyUri: spotifyUri, asRadio: swiftArguments[SpotifySdkConstants.paramAsRadio] as? Bool, additionalScopes: swiftArguments[SpotifySdkConstants.scope] as? String)
        }
        catch SpotifyError.redirectURLInvalid {
            result(SpotifyErrorMapper.makeError(code: "errorConnecting", message: "Redirect URL is not set or has invalid format"))
        }
        catch {
            result(SpotifyErrorMapper.makeError(code: "CouldNotFindSpotifyApp", message: "The Spotify app is not installed on the device"))
        }
    }

    public func isSpotifyInstalled(result: @escaping FlutterResult) {
        result(UIApplication.shared.canOpenURL(URL(string: "spotify:")!))
    }

    public func disconnect(result: @escaping FlutterResult) {
        remoteManager.appRemote?.disconnect()
        result(true)
    }

    /// The token the live remote holds (set by the authorize redirect or a
    /// prior connect). Read without waking Spotify, so a caller can reconnect
    /// silently by passing it back to connectToSpotifyRemote.
    public func getStoredAccessToken(result: @escaping FlutterResult) {
        result(remoteManager.appRemote?.connectionParameters.accessToken)
    }

    private func connectToSpotifyInternal(clientId: String, redirectURL: String, accessToken: String? = nil, spotifyUri: String = "", asRadio: Bool? = false, additionalScopes: String? = nil) throws {
        guard let redirectURL = URL(string: redirectURL) else {
            throw SpotifyError.redirectURLInvalid
        }

        let appRemote = remoteManager.appRemote(clientID: clientId, redirectURL: redirectURL, reuse: accessToken != nil)
        appRemote.delegate = remoteManager.connectionStatusHandler
        appRemote.connectionParameters.accessToken = accessToken

        if remoteManager.playerStateHandler == nil {
            remoteManager.playerStateHandler = PlayerStateHandler(remoteManager: remoteManager)
            RemoteManager.playerStateChannel?.setStreamHandler(remoteManager.playerStateHandler)
        }
        if remoteManager.playerContextHandler == nil {
            remoteManager.playerContextHandler = PlayerContextHandler(remoteManager: remoteManager)
            RemoteManager.playerContextChannel?.setStreamHandler(remoteManager.playerContextHandler)
        }
        if remoteManager.capabilitiesHandler == nil {
            remoteManager.capabilitiesHandler = CapabilitiesHandler()
            RemoteManager.capabilitiesChannel?.setStreamHandler(remoteManager.capabilitiesHandler)
        }
        remoteManager.capabilitiesHandler?.setAppRemote(appRemote)

        var scopes: [String]?
        if let additionalScopes = additionalScopes {
            scopes = additionalScopes.components(separatedBy: ",")
        }

        if accessToken != nil {
            if appRemote.isConnected {
                // The reused remote is already live; a second connect() would not
                // fire the delegate again and the Dart result would hang.
                remoteManager.connectionStatusHandler?.appRemoteDidEstablishConnection(appRemote)
            } else {
                appRemote.connect()
            }
        } else {
            let stateBefore = UIApplication.shared.applicationState.rawValue
            appRemote.authorizeAndPlayURI(spotifyUri, asRadio: asRadio ?? false, additionalScopes: scopes) { success in
                if (!success) {
                    // The SDK answers false for "not installed" and for a refused URL
                    // open alike; the app state and scheme check tell them apart.
                    let canOpen = UIApplication.shared.canOpenURL(URL(string: "spotify-action://")!)
                    let details = "applicationState before=\(stateBefore) now=\(UIApplication.shared.applicationState.rawValue) canOpen(spotify-action)=\(canOpen) uri=\(spotifyUri)"
                    NSLog("spotify_sdk_ios: authorizeAndPlayURI refused — \(details)")
                    self.remoteManager.connectionStatusHandler?.connectionResult?(FlutterError(code: "spotifyNotInstalled", message: "Spotify app is not installed", details: details))
                    self.remoteManager.connectionStatusHandler?.tokenResult?(FlutterError(code: "spotifyNotInstalled", message: "Spotify app is not installed", details: details))
                    self.remoteManager.connectionStatusHandler?.connectionResult = nil
                    self.remoteManager.connectionStatusHandler?.tokenResult = nil
                }
            }
        }
    }
}

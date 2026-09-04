import Flutter
import SpotifyiOS

class ConnectionStatusHandler: StatusHandler, SPTAppRemoteDelegate {

    var tokenResult: FlutterResult?
    var connectionResult: FlutterResult?
    
    func appRemoteDidEstablishConnection(_ appRemote: SPTAppRemote) {
        RemoteManager.shared.markConnectionEstablished()
        RemoteManager.shared.capabilitiesHandler?.setAppRemote(appRemote)
        RemoteManager.shared.playerStateHandler?.subscribe()
        RemoteManager.shared.userStatusHandler?.updateConnectionStatus(isConnected: true)

        connectionResult?(true)
        tokenResult?(appRemote.connectionParameters.accessToken)
        eventSink?("{\"connected\": true}")

        connectionResult = nil
        tokenResult = nil
    }

    func appRemote(_ appRemote: SPTAppRemote, didFailConnectionAttemptWithError error: Error?) {
        RemoteManager.shared.markConnectionAttemptFailed()
        RemoteManager.shared.playerStateHandler?.resetSubscription()
        RemoteManager.shared.userStatusHandler?.updateConnectionStatus(isConnected: false)
        defer {
            connectionResult = nil
            tokenResult = nil
        }

        if let error = error {
            // The SDK's localizedDescription is generic ("Connection attempt
            // failed."); the NSError domain and userInfo carry the actual cause.
            let nsError = error as NSError
            let details = "\(nsError.domain) \(nsError.code): \(nsError.localizedDescription) \(nsError.userInfo)"
            eventSink?("{\"connected\": false, \"errorCode\": \"\(nsError.code)\", \"errorDetails\": \"\(details.replacingOccurrences(of: "\"", with: "'"))\"}")
            connectionResult?(FlutterError(code: String(nsError.code), message: nsError.localizedDescription, details: details))
            tokenResult?(FlutterError(code: String(nsError.code), message: nsError.localizedDescription, details: details))
        } else {
            // report disconnection to plugin
            eventSink?("{\"connected\": false}")
            connectionResult?(FlutterError(code: "errorConnection", message: "Failed Connection Attempt", details: nil))
            tokenResult?(FlutterError(code: "errorConnection", message: "Failed Connection Attempt", details: nil))
        }
    }

    func appRemote(_ appRemote: SPTAppRemote, didDisconnectWithError error: Error?) {
        RemoteManager.shared.playerStateHandler?.resetSubscription()
        RemoteManager.shared.userStatusHandler?.updateConnectionStatus(isConnected: false)
        if error != nil {
            // report spotify remote error to plugin
            eventSink?("{\"connected\": false, \"errorCode\": \"\(error!._code)\", \"errorDetails\": \"\(error!.localizedDescription)\"}")
        } else {
            // report disconnection to plugin
            eventSink?("{\"connected\": false}")
        }
    }
}

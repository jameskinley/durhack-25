//
//  SpotifyAuthManager.swift
//  GeoGroove
//
//  Created by Alex on 01/11/2025.
//

import Foundation
import AuthenticationServices
import CryptoKit
import Combine

/// Spotify authentication manager using Authorization Code Flow with PKCE.
///
/// IMPORTANT: Replace `clientId` and `redirectURI` with values from your Spotify developer app.
/// Register the `redirectURI` in the Spotify Dashboard and add the same scheme to your
/// app's Info.plist (e.g. `geogroove://callback`).
final class SpotifyAuthManager: NSObject, ObservableObject {
    static let shared = SpotifyAuthManager()

    private let clientId = "069c9babefeb4fd693c7599d729c1ec8"
    private let redirectURI = "geogroove://spotify-callback"
    // Include playback scopes so we can start playback on the user's device
    private let scopes = "user-read-private user-read-email streaming user-modify-playback-state user-read-playback-state"

    @Published var isConnected: Bool = false
    @Published var accessToken: String?
    @Published var refreshToken: String?

    private var currentSession: ASWebAuthenticationSession?
    private var codeVerifier: String?

    private override init() {
        super.init()
        // Try to restore tokens (placeholder - use Keychain in production)
        if let token = UserDefaults.standard.string(forKey: "spotify_access_token") {
            self.accessToken = token
            self.isConnected = true
        }
    }

    /// Start the Spotify sign-in flow.
    /// Calls completion(true) on success.
    func startAuthentication(completion: ((Bool) -> Void)? = nil) {
        // generate PKCE codes
        let verifier = Self.generateCodeVerifier()
        self.codeVerifier = verifier
        guard let challenge = Self.codeChallenge(for: verifier) else {
            completion?(false)
            return
        }

        // Build authorization URL
        var components = URLComponents(string: "https://accounts.spotify.com/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "scope", value: scopes),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "show_dialog", value: "true")
        ]

        guard let authURL = components.url else {
            completion?(false)
            return
        }

        // Extract the scheme for the callback
        let callbackScheme = URL(string: redirectURI)?.scheme

        let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: callbackScheme) { [weak self] callbackURL, error in
            guard let self = self else { return }
            if let error = error {
                print("Spotify auth error: \(error)")
                completion?(false)
                return
            }

            guard let callbackURL = callbackURL,
                  let comps = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                  let code = comps.queryItems?.first(where: { $0.name == "code" })?.value else {
                completion?(false)
                return
            }

            // Exchange the authorization code for tokens
            self.exchangeCodeForToken(code: code) { success in
                DispatchQueue.main.async {
                    self.isConnected = success
                    completion?(success)
                }
            }
        }

        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = false
        self.currentSession = session
        session.start()
    }

    private func exchangeCodeForToken(code: String, completion: @escaping (Bool) -> Void) {
        guard let verifier = codeVerifier else {
            completion(false)
            return
        }

        let tokenURL = URL(string: "https://accounts.spotify.com/api/token")!
        var req = URLRequest(url: tokenURL)
        req.httpMethod = "POST"
        let bodyParams: [String: String] = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": redirectURI,
            "client_id": clientId,
            "code_verifier": verifier
        ]
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = bodyParams.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }.joined(separator: "&").data(using: .utf8)

        let task = URLSession.shared.dataTask(with: req) { data, resp, err in
            if let err = err {
                print("Token exchange error: \(err)")
                completion(false); return
            }
            guard let data = data else { completion(false); return }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let access = json["access_token"] as? String {
                        self.accessToken = access
                        self.refreshToken = json["refresh_token"] as? String
                        // Persist tokens securely (Keychain recommended)
                        UserDefaults.standard.set(access, forKey: "spotify_access_token")
                        if let refresh = self.refreshToken {
                            UserDefaults.standard.set(refresh, forKey: "spotify_refresh_token")
                        }
                        completion(true)
                        return
                    } else {
                        print("No access token in response: \(json)")
                    }
                }
            } catch {
                print("Error parsing token response: \(error)")
            }

            completion(false)
        }

        task.resume()
    }

    /// Send a play command to the Spotify Web API to start playback of the given track URI
    /// Example track URI for Rick Astley: "spotify:track:4uLU6hMCjMI75M1A2tKUQC"
    func play(trackURI: String, completion: @escaping (Bool, String?) -> Void) {
        guard let token = accessToken else {
            completion(false, "No access token available")
            return
        }

        let url = URL(string: "https://api.spotify.com/v1/me/player/play")!
        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["uris": [trackURI]]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let task = URLSession.shared.dataTask(with: req) { data, resp, err in
            if let err = err {
                completion(false, "Network error: \(err.localizedDescription)")
                return
            }

            if let http = resp as? HTTPURLResponse {
                switch http.statusCode {
                case 204:
                    completion(true, nil)
                case 202:
                    // Accepted - may start soon
                    completion(true, nil)
                case 401:
                    completion(false, "Unauthorized - token may have expired")
                case 404:
                    completion(false, "No active Spotify device found. Start Spotify on a device and try again.")
                default:
                    let bodyStr = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                    completion(false, "HTTP \(http.statusCode): \(bodyStr)")
                }
            } else {
                completion(false, "Unknown response")
            }
        }

        task.resume()
    }

    /// Play an ordered list of Spotify URIs. This will attempt to start playback with the provided
    /// URIs in the order given. Uses the same `/v1/me/player/play` endpoint with the `uris` array.
    func play(uris: [String], completion: @escaping (Bool, String?) -> Void) {
        guard let token = accessToken else {
            completion(false, "No access token available")
            return
        }

        let url = URL(string: "https://api.spotify.com/v1/me/player/play")!
        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["uris": uris]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let task = URLSession.shared.dataTask(with: req) { data, resp, err in
            if let err = err {
                completion(false, "Network error: \(err.localizedDescription)")
                return
            }

            if let http = resp as? HTTPURLResponse {
                switch http.statusCode {
                case 204:
                    completion(true, nil)
                case 202:
                    completion(true, nil)
                case 401:
                    completion(false, "Unauthorized - token may have expired")
                case 404:
                    completion(false, "No active Spotify device found. Start Spotify on a device and try again.")
                default:
                    let bodyStr = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                    completion(false, "HTTP \(http.statusCode): \(bodyStr)")
                }
            } else {
                completion(false, "Unknown response")
            }
        }

        task.resume()
    }

    /// Play an ordered list of Spotify URIs and optionally start at a given index offset.
    func play(uris: [String], startIndex: Int?, completion: @escaping (Bool, String?) -> Void) {
        guard let token = accessToken else {
            completion(false, "No access token available")
            return
        }

        let url = URL(string: "https://api.spotify.com/v1/me/player/play")!
        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = ["uris": uris]
        if let idx = startIndex {
            body["offset"] = ["position": idx]
        }

        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let task = URLSession.shared.dataTask(with: req) { data, resp, err in
            if let err = err {
                completion(false, "Network error: \(err.localizedDescription)")
                return
            }

            if let http = resp as? HTTPURLResponse {
                switch http.statusCode {
                case 204:
                    completion(true, nil)
                case 202:
                    completion(true, nil)
                case 401:
                    completion(false, "Unauthorized - token may have expired")
                case 404:
                    completion(false, "No active Spotify device found. Start Spotify on a device and try again.")
                default:
                    let bodyStr = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                    completion(false, "HTTP \(http.statusCode): \(bodyStr)")
                }
            } else {
                completion(false, "Unknown response")
            }
        }

        task.resume()
    }

    /// Pause playback on the user's active Spotify device.
    func pause(completion: @escaping (Bool, String?) -> Void) {
        guard let token = accessToken else {
            completion(false, "No access token available")
            return
        }

        let url = URL(string: "https://api.spotify.com/v1/me/player/pause")!
        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let task = URLSession.shared.dataTask(with: req) { data, resp, err in
            if let err = err {
                completion(false, "Network error: \(err.localizedDescription)")
                return
            }

            if let http = resp as? HTTPURLResponse {
                switch http.statusCode {
                case 204:
                    completion(true, nil)
                case 202:
                    completion(true, nil)
                case 401:
                    completion(false, "Unauthorized - token may have expired")
                default:
                    let bodyStr = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                    completion(false, "HTTP \(http.statusCode): \(bodyStr)")
                }
            } else {
                completion(false, "Unknown response")
            }
        }

        task.resume()
    }

    // MARK: - PKCE helpers
    private static func generateCodeVerifier() -> String {
        let length = 128
        let chars = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        var s = ""
        for _ in 0..<length { s.append(chars.randomElement()!) }
        return s
    }

    private static func codeChallenge(for verifier: String) -> String? {
        guard let data = verifier.data(using: .utf8) else { return nil }
        let hashed = SHA256.hash(data: data)
        let challenge = Data(hashed).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return challenge
    }
}

extension SpotifyAuthManager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Return key window's windowScene anchor if available
        return UIApplication.shared.windows.first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}

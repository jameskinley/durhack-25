//
//  Supabase.swift
//  GeoGroove
//
//  Created by Alex on 02/11/2025.
//

import Foundation
import Supabase

// MARK: - Data Models

/// Response from the "create-journey" function.
struct CreateJourneyRequest: Codable {
	let preferences: [String]
}

struct CreateJourneyResponse: Codable {
	let ok: Bool
	let id: String
}

/// Location point for curate-playlist.
struct LocationPoint: Codable {
	let x: Double
	let y: Double
}

/// Request for the "curate-playlist" function.
struct CuratePlaylistRequest: Codable {
	let journeyId: String
	let points: [LocationPoint]
	let duration: [Int] // in seconds
}

/// A track returned from "curate-playlist".
struct PlaylistTrack: Codable, Identifiable {
	let track: String
	let artist: String
	let artist_tags: [String]?
	let location: LocationPoint
	let comment: String?
	let type: String // "track" or "bio"

	var id: String { track + "-" + artist } // Simple id for Identifiable
}

// MARK: - Supabase Service

/// Supabase service wrapper that uses the official `supabase-swift` library to call
/// the Edge Functions: "create-journey" and "curate-playlist".
///
/// Configuration:
/// - Add `SUPABASE_URL` and `SUPABASE_ANON_KEY` to your Info.plist (or set them in code).
final class SupabaseService {
	static let shared = SupabaseService()

	private let supabaseUrl: String?
	private let supabaseKey: String?
	private let client: SupabaseClient?

	private init() {
		supabaseUrl = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String
		supabaseKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String

		if let urlStr = supabaseUrl, let key = supabaseKey, let url = URL(string: urlStr) {
			// Create the library client
			client = SupabaseClient(supabaseURL: url, supabaseKey: key)
		} else {
			client = nil
		}
	}

	enum SupabaseError: Error {
		case missingConfig
		case noClient
		case decodingError
		case serverError(statusCode: Int)
		case networkError(Error)
	}

	/// Step 1: Create a journey with preferences, returning the journey ID.
	func createJourney(preferences: [String], completion: @escaping (Result<String, Error>) -> Void) {
		guard let client = client else {
			completion(.failure(SupabaseError.missingConfig))
			return
		}

		let request = CreateJourneyRequest(preferences: preferences)
		
		Task {
			do {
				let response: CreateJourneyResponse = try await client.functions.invoke(
					"create-journey",
					options: FunctionInvokeOptions(
						body: request
					)
				)
				completion(.success(response.id))
			} catch {
				completion(.failure(error))
			}
		}
	}

	/// Step 2: Curate a playlist for the given journey with route points and duration.
	func curatePlaylist(journeyId: String, points: [LocationPoint], duration: [Int], completion: @escaping (Result<[PlaylistTrack], Error>) -> Void) {
		guard let client = client else {
			completion(.failure(SupabaseError.missingConfig))
			return
		}

		let request = CuratePlaylistRequest(journeyId: journeyId, points: points, duration: duration)
		
		Task {
			do {
				let tracks: [PlaylistTrack] = try await client.functions.invoke(
					"curate-playlist",
					options: FunctionInvokeOptions(
						body: request
					)
				)
				completion(.success(tracks))
			} catch {
				completion(.failure(error))
			}
		}
	}
}

//
//  YTExtractor.swift
//  
//
//  Created by Dani on 3/5/23.
//

import Foundation
import RegexBuilder
import YoutubeKit

struct YTExtractor {
    
    static func videoURL(for id: String) -> URL {
        URL(string: "https://www.youtube.com/watch?v=\(id)")!
    }
    
    static let playerAPIURL: URL = URL(string: "https://www.youtube.com/youtubei/v1/player")!
    static let videoIDRegex: Regex = #/v=(.{11})/#
    
    func video(for videoURL: URL) async throws -> YTVideo {
        let videoID = try await videoID(for: videoURL)
        
        return try await throwingYTError {
            var request = URLRequest(url: Self.playerAPIURL)
            request.httpMethod = "POST"
            request.setValue("application/json;charset=UTF-8", forHTTPHeaderField: "Content-Type")
            let requestBody = requestBody(videoID: videoID)
            let requestBodyData = try JSONSerialization.data(withJSONObject: requestBody)
            request.httpBody = requestBodyData
            
            let (responseData, _) = try await URLSession.shared.data(for: request)
            guard let responseJSON = try JSONSerialization.jsonObject(with: responseData) as? [String : Any],
                  let videoDetails = responseJSON["videoDetails"],
                  let videoFormats = (responseJSON["streamingData"] as? [String : Any])?["formats"],
                  let videoAdaptiveFormats = (responseJSON["streamingData"] as? [String : Any])?["adaptiveFormats"] else {
                throw YTError.parsingError()
            }
            
            let detailsJSON = try JSONSerialization.data(withJSONObject: videoDetails)
            let details = try JSONDecoder().decode(YTVideoDetails.self, from: detailsJSON)
            
            let formatsJSON = try JSONSerialization.data(withJSONObject: videoFormats)
            var formats = try JSONDecoder().decode([YTVideoFormat].self, from: formatsJSON)
            
            let apaptiveFormatsJSON = try JSONSerialization.data(withJSONObject: videoAdaptiveFormats)
            formats.append(contentsOf: try JSONDecoder().decode([YTVideoFormat].self, from: apaptiveFormatsJSON))
            
            return YTVideo(details: details, formats: formats)
        }
    }
    
    static func playlistURL(for id: String) -> URL {
        URL(string: "https://www.youtube.com/playlist?list=\(id)")!
    }
    
    func videos(playlistID: String, nextPageToken: String? = nil) async throws -> (YTPlaylist, [YTVideo]) {
        
        YoutubeKit.shared.setAPIKey("AIzaSyCbGMAauH9JGOClZsI_qyU_oO5UqaNkIOU")
        
        let request = PlaylistItemsListRequest(part: [.contentDetails, .snippet, .status], filter: .playlistID(playlistID), pageToken: nextPageToken)
        
        let response = try await YoutubeAPI.shared.send(request)
        
        var videos = [YTVideo]()
        
        for videoID in response.items.map({ $0.contentDetails.videoID }) {
            do {
                videos.append(try await video(for: Self.videoURL(for: videoID)))
            } catch {
                print("Skipping video: \(videoID)")
            }
        }
        
        let playlist: YTPlaylist
        
        if let nextPageToken = response.nextPageToken {
            let nextPage = try await self.videos(playlistID: playlistID, nextPageToken: nextPageToken)
            playlist = nextPage.0
            videos.append(contentsOf: nextPage.1)
        } else {
            let playlistInfoResponse = try await YoutubeAPI.shared.send(PlaylistsListRequest(part: [.snippet, .status, .id], filter: .id(playlistID)))
            guard let snippet = playlistInfoResponse.items.first?.snippet else {
                throw YTError.parsingError(context: .init(message: "Failed to get playlist information."))
            }
            playlist = YTPlaylist(details: snippet)
        }
        
        return (playlist, videos)
    }
    
    func videos(channelID: String, nextPageToken: String? = nil) async throws -> (YTChannel, [YTVideo]) {
        
        YoutubeKit.shared.setAPIKey("AIzaSyCbGMAauH9JGOClZsI_qyU_oO5UqaNkIOU")
        
        let channelInfoResponse = try await YoutubeAPI.shared.send(ChannelListRequest(part: [.snippet, .id, .contentDetails, .topicDetails, .brandingSettings, .statistics], filter: .userName(channelID)))
        
        guard let snippet = channelInfoResponse.items.first?.snippet else {
            throw YTError.parsingError(context: .init(message: "Failed to get channel information."))
        }
        let channel = YTChannel(details: snippet)
        
        guard let allVideosPlaylistID = channelInfoResponse.items.first?.contentDetails?.relatedPlaylists.uploads else {
            throw YTError.parsingError(context: .init(message: "Failed to get channel videos."))
        }
        
        let videos = try await videos(playlistID: allVideosPlaylistID).1
        
        return (channel, videos)
    }
    
    func videoID(for videoURL: URL) async throws -> String {
        guard let lastComponent = videoURL.query() else {
            throw YTError.invalidURL()
        }
        return try await throwingYTError {
            guard let (_, videoID) = try Self.videoIDRegex.firstMatch(in: lastComponent)?.output else {
                throw YTError.invalidURL()
            }
            return String(videoID)
        }
    }
    
    func requestBody(videoID: String) -> [String : Any] {
        [
            "videoId": videoID,
            "context": [
                "client": [
                    "clientName": "WEB_EMBEDDED_PLAYER",
                    "clientVersion": "1.20230430.00.00"
                ]
            ]
        ]
    }
    
    func throwingYTError<T>(_ code: () async throws -> T) async throws -> T {
        do {
            return try await code()
        } catch {
            if let error = error as? YTError {
                throw error
            }
            throw YTError.unknown(context: YTError.Context(underlyingError: error))
        }
    }
}

extension YoutubeAPI {
    
    func send<T: Requestable>(_ request: T, queue: DispatchQueue = .main) async throws -> T.Response {
        
        try await withCheckedThrowingContinuation { continuation in
            send(request, queue: queue) { result in
                continuation.resume(with: result)
            }
        }
    }
}

//
//  YTVideo.swift
//  
//
//  Created by Dani on 4/5/23.
//

import Foundation
import YoutubeKit

public struct YTVideo {
    public var details: YTVideoDetails
    public var formats: [YTVideoFormat]?
    public var thumbnails: Thumbnails.VideoList?
    public var tags: [String]?
    
    public var availableQualities: [YTVideoFormat.Quality] {
        formats?.map { $0.quality } ?? []
    }
}
extension YTVideo: Identifiable, Hashable {
    
    public static func == (lhs: YouTubeDLKit.YTVideo, rhs: YouTubeDLKit.YTVideo) -> Bool {
        lhs.id == rhs.id
    }
    
    public var id: String {
        self.details.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

public struct YTPlaylist {
    
    public var playlistID: String
    public var details: Snippet.PlaylistsList
    public var thumbnails: Thumbnails.PlaylistsList?
}
extension YTPlaylist: Identifiable, Hashable {
    
    public static func == (lhs: YouTubeDLKit.YTPlaylist, rhs: YouTubeDLKit.YTPlaylist) -> Bool {
        lhs.id == rhs.id
    }
    
    public var id: String {
        self.playlistID
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

public struct YTChannel {
    
    public var channelID: String
    public var details: Snippet.ChannelList
    public var thumbnails: Thumbnails.ChannelList?
}
extension YTChannel: Identifiable, Hashable {
    
    public static func == (lhs: YouTubeDLKit.YTChannel, rhs: YouTubeDLKit.YTChannel) -> Bool {
        lhs.id == rhs.id
    }
    
    public var id: String {
        self.channelID
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

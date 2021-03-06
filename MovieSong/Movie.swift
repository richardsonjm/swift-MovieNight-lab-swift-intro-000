//
//  Movie.swift
//  MovieSong
//
//  Created by Jim Campagno on 8/20/16.
//  Copyright © 2016 Gamesmith, LLC. All rights reserved.
//

import Foundation
import UIKit

protocol MovieImageDelegate {
    
    func imageUpdate(withMovie movie: Movie)
    
}

final class Movie {
    
    // TODO: Instruction #1, create instance properties
    let title: String
    let year: String
    let imdbID: String
    var posterURLString: String?

    // TODO: Instruction #4, create more instance properties
    var hasFullInfo = false
    var rated = "No Rating"
    var released = "No Release Date"
    var director = "No Director"
    var imdbRating = "N/A"
    var tomatoMeter = "N'A"
    var plot = "No Plot"
    
    var attemptedToDownloadImage = false
    var movieImageDelegate: MovieImageDelegate?
    var shouldKickOffImageDownload: Bool { return shouldKickOffTheDownload() }
    var image: UIImage? { return retrieveImage() }
    var imageState = MovieImageState() {
        didSet {
            movieImageDelegate?.imageUpdate(withMovie: self)
        }
    }
    
    
    // TODO: Instruction #2, create Initializer 
    init(movieJSON: [String: String]) {
        title = movieJSON["Title"] ?? "No Title"
        year = movieJSON["Year"] ?? "No Year"
        imdbID = movieJSON["imdbID"] ?? "No IMDBID"
        posterURLString = movieJSON["Poster"]
    }

    
    // TODO: Instruction #4, create the updateFilmInfo(_:) method
    func updateFilmInfo(_ jsonResponse: [String: String]) {
        rated = jsonResponse["Rated"] ?? "No Rating"
        released = jsonResponse["Released"] ?? "No Release Date"
        director = jsonResponse["Director"] ?? "No Director"
        imdbRating = jsonResponse["imdbRating"] ?? "N/A"
        tomatoMeter = jsonResponse["tomatoMeter"] ?? "N/A"
        plot = jsonResponse["Plot"] ?? "No Plot"
    }
}


// MARK: Image Methods
extension Movie {
    
    private func retrieveImage() -> UIImage? {
        switch imageState {
        case .Loading(let image):
            if shouldKickOffImageDownload { downloadImage() }
            return image
        case .Downloaded(let image): return image
        case .NoImage(let image): return image
        case .Nothing:
            if shouldKickOffImageDownload {  downloadImage() }
            return nil
        }
    }
    
    func noImage() {
        imageState.noImage()
    }
    
    func loadingImage() {
        imageState.loadingImage()
    }
    
    func nothingImage() {
        imageState.nothingImage()
    }
    
}

// MARK: Download Image Methods
extension Movie {
    
    func downloadImage()  {
        nothingImage()
        loadingImage()
        guard !attemptedToDownloadImage else { return }
        attemptedToDownloadImage = true
        guard let posterURLString = posterURLString, let posterURL = NSURL(string: posterURLString) else { noImage(); return }
        downloadImage(withURL: posterURL)
    }
    
    func downloadImage(withURL URL: NSURL) {
        let defaultSession = NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration())
        
        defaultSession.dataTaskWithURL(URL) { data, response, error in
            dispatch_async(dispatch_get_main_queue(),{
                if error != nil || data == nil { self.noImage() }
                if data != nil {
                    let image = UIImage(data: data!)
                    if image == nil {
                       self.noImage()
                    } else {
                        self.imageState = .Downloaded(image!)
                    }
                }
            })
            }.resume()
    }
    
    private func shouldKickOffTheDownload() -> Bool {
        switch (imageState, attemptedToDownloadImage) {
        case (.Loading(_), false): return true
        case (.Nothing, false): return true
        default: return false
        }
    }
    
}


// MARK: Update Info
extension Movie {
    
    func updateInfo(handler handler: (Bool) -> Void) throws {
        
        let defaultSession = NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration())

        guard let urlString = imdbID.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())
            else { throw MovieError.BadSearchString("Unable to encode \(title) to use within our search.") }
        
        guard let searchURL = NSURL(string: "http://www.omdbapi.com/?i=\(urlString)&plot=full&r=json&tomatoes=true")
            else { throw MovieError.BadSearchURL("Unable to create URL with the search term: \(title)") }
        
        defaultSession.dataTaskWithURL(searchURL) { [unowned self] data, response, error in
            dispatch_async(dispatch_get_main_queue(),{
                if error != nil { handler(false) }
                if data == nil { handler(false) }
                
                guard let jsonResponse = try? NSJSONSerialization.JSONObjectWithData(data!, options: .MutableContainers) as! JSONResponseDictionary
                    else { handler(false); return }
                            
                self.updateFilmInfo(jsonResponse)
            
                self.hasFullInfo = true

                handler(true)
            })
            }.resume()
    }

}


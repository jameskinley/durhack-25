//
//  AddressSearchViewModel.swift
//  GeoGroove
//
//  Created by Alex on 01/11/2025.
//

import Foundation
import MapKit
import Combine

class AddressSearchViewModel: NSObject, ObservableObject {
    @Published var searchQuery: String = ""
    @Published var searchResults: [MKLocalSearchCompletion] = []
    
    private let searchCompleter = MKLocalSearchCompleter()
    private var cancellables = Set<AnyCancellable>()
    
    override init() {
        super.init()
        searchCompleter.delegate = self
        searchCompleter.resultTypes = .address
        
        // Debounce search query to avoid too many requests
        $searchQuery
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] query in
                self?.updateSearchResults(query: query)
            }
            .store(in: &cancellables)
    }
    
    private func updateSearchResults(query: String) {
        if query.isEmpty {
            searchResults = []
            searchCompleter.cancel()
        } else {
            searchCompleter.queryFragment = query
        }
    }
    
    func selectLocation(_ completion: MKLocalSearchCompletion, completionHandler: @escaping (CLLocationCoordinate2D?) -> Void) {
        let searchRequest = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: searchRequest)
        
        search.start { response, error in
            guard let coordinate = response?.mapItems.first?.placemark.coordinate else {
                completionHandler(nil)
                return
            }
            completionHandler(coordinate)
        }
    }
}

extension AddressSearchViewModel: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        searchResults = completer.results
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("Address search error: \(error.localizedDescription)")
    }
}

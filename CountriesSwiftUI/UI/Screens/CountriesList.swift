//
//  CountriesList.swift
//  CountriesSwiftUI
//
//  Created by Alexey Naumov on 24.10.2019.
//  Copyright © 2019 Alexey Naumov. All rights reserved.
//

import SwiftUI
import Combine

// MARK: - Routing

extension CountriesList {
    struct Routing: Equatable {
        var countryDetails: Country.Code?
    }
}

// MARK: - State Updates Filtering

extension CountriesList {
    struct StateSnapshot: Equatable {
        let countries: Loadable<[Country]>
        let routing: Routing
    }
}

extension AppState {
    var countriesListStateSnapshot: CountriesList.StateSnapshot {
        .init(countries: userData.countries, routing: routing.countriesList)
    }
}

// MARK: - CountriesList

struct CountriesList: View {
    
    @EnvironmentObject var appState: Deduplicated<AppState, StateSnapshot>
    @Environment(\.interactors) var interactors: InteractorsContainer
    private let cancelBag = CancelBag()
    @State private var showDetailView: Bool = false
    /// hardcoded just for showing the network request bug when loading the country detail as a modal
    let country = Country(name: "Bahrain", population: 1, flag: URL(string: "https://restcountries.eu/data/bhr.svg"), alpha3Code: "BHR")
    
    var body: some View {
        GeometryReader { geometry in
            NavigationView {
                self.content
                    .navigationBarTitle("Countries")
                    .navigationBarItems(trailing:
                        HStack {
                            Button(action: {
                                self.showDetailView.toggle()
                            }, label: {Image(systemName: "plus")})
                                .sheet(isPresented: self.$showDetailView) {
                                    CountryDetails(country: self.country)
                                        .environmentObject(self.appState)
                                        .environment(\.interactors, self.interactors)
                            }
                        }
                )
            }.padding(.leading, self.leadingPadding(geometry))
        }
    }
    
    private var content: AnyView {
        switch appState.userData.countries {
        case .notRequested: return AnyView(notRequestedView)
        case let .isLoading(last): return AnyView(loadingView(last))
        case let .loaded(countries): return AnyView(loadedView(countries))
        case let .failed(error): return AnyView(failedView(error))
        }
    }
    
    private func leadingPadding(_ geometry: GeometryProxy) -> CGFloat {
        if UIDevice.current.userInterfaceIdiom == .pad {
            // A hack for correct display of the SplitView on iPads
            return geometry.size.width < geometry.size.height ? 0.5 : -0.5
        }
        return 0
    }
}

// MARK: - Side Effects

private extension CountriesList {
    func loadCountries() {
        interactors.countriesInteractor.loadCountries()
            .store(in: cancelBag)
    }
}

// MARK: - Loading Content

private extension CountriesList {
    var notRequestedView: some View {
        Text("").onAppear {
            self.loadCountries()
        }
    }
    
    func loadingView(_ previouslyLoaded: [Country]?) -> some View {
        VStack {
            ActivityIndicatorView().padding()
            previouslyLoaded.map {
                loadedView($0)
            }
        }
    }
    
    func failedView(_ error: Error) -> some View {
        ErrorView(error: error, retryAction: {
            self.loadCountries()
        })
    }
}

// MARK: - Displaying Content

private extension CountriesList {
    func loadedView(_ countries: [Country]) -> some View {
        return List(countries) { country in
            NavigationLink(
                destination: self.detailsView(country: country),
                tag: country.alpha3Code,
                selection: self.$appState.routing.countriesList.countryDetails) {
                    CountryCell(country: country)
                }
        }
    }
    
    func detailsView(country: Country) -> some View {
        CountryDetails(country: country)
    }
}

#if DEBUG
struct CountriesList_Previews: PreviewProvider {
    static var appState = AppState.preview
    static var previews: some View {
        CountriesList()
            .environmentObject(appState)
    }
}
#endif

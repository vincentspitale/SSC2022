//
//  ExamplePhotosPicker.swift
//  
//
//  Created by Vincent Spitale on 4/22/22.
//

import Foundation
import Combine
import SwiftUI
import UIKit

struct ExamplePhotosView: UIViewControllerRepresentable {
    typealias UIViewControllerType = ExamplePhotosController
    var windowState: WindowState
    
    func makeUIViewController(context: Context) -> ExamplePhotosController {
        ExamplePhotosController(windowState: windowState)
    }
    
    func updateUIViewController(_ uiViewController: ExamplePhotosController, context: Context) {
        
    }
    
}

class ExamplePhotosController: UIViewController {
    var state: WindowState
    var picker: UIHostingController<ExamplePhotosNavigationView>?
    var cancellable: AnyCancellable? = nil
    
    init(windowState: WindowState) {
        self.state = windowState
        super.init(nibName: nil, bundle: nil)
        self.cancellable = state.$photoMode.sink(receiveValue: { [weak self] mode in
            guard let self = self else { return }
            if mode == .example  {
                let picker = UIHostingController(rootView: ExamplePhotosNavigationView(windowState: windowState))
                self.picker = picker
                self.present(picker, animated: true)
            } else {
                self.picker?.dismiss(animated: true)
            }
        })
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

struct ExamplePhotosNavigationView: View {
    @ObservedObject var windowState: WindowState
    let photoColumns = [GridItem](repeating: GridItem(.flexible(), spacing: 1), count: 3)
    
    var body: some View {
        NavigationView {
            VStack {
                LazyVGrid(columns: photoColumns, spacing: 1) {
                    ForEach(ExamplePhotos.photos, id: \.self) { image in
                        Button(action: { self.convert(image: image) } ) {
                            Rectangle()
                                .aspectRatio(1, contentMode: .fit)
                                .overlay(
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                )
                                .clipShape(Rectangle())
                        }
                    }
                }
                Spacer()
            }
            .navigationTitle("Example Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", action: { self.cancel() })
                }
            }
        }
        .navigationViewStyle(.stack)
    }
    
    func cancel() {
        self.windowState.photoMode = .none
    }
    
    func convert(image: UIImage) {
        self.windowState.photoMode = .none
        Task { @MainActor in
            await self.windowState.startConversion(image: image)
        }
    }
    
}

class ExamplePhotos {
    static var photos: [UIImage] = {
        [ UIImage(named: "example1.heic"),
          UIImage(named: "example2.jpg"),
          UIImage(named: "example3.jpg"),
          UIImage(named: "example4.jpg")].compactMap { $0 }
    }()
}

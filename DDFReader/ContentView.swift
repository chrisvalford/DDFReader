//
//  ContentView.swift
//  DDFReader
//
//  Created by Christopher Alford on 27/4/21.
//

import SwiftUI

struct DocumentPicker : UIViewControllerRepresentable {
    
    var callback : ([URL]?) -> Void
    @Environment(\.presentationMode) var presentationMode
    
    class Coordinator : NSObject, UIDocumentPickerDelegate {
        var parent : DocumentPicker
        
        init(_ parent : DocumentPicker){
            self.parent = parent
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            self.parent.callback(nil)
            print("Cancelled picking document")
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            self.parent.callback(urls)
            self.parent.presentationMode.wrappedValue.dismiss()
        }
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }

   func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

   func makeUIViewController(context: Context) ->  UIDocumentPickerViewController {
        let options = ["public.image", "public.jpeg", "public.png", "public.pdf", "public.text", "public.video", "public.audio", "public.text", "public.data", "public.zip-archive"]
        
        let picker  = UIDocumentPickerViewController(documentTypes: options, in: .import)
        picker.allowsMultipleSelection = true
        picker.modalPresentationStyle = .fullScreen
        picker.delegate = context.coordinator
        return picker
    }
}


struct ContentView: View {
    
    @State private var showDocumentPicker = false
    @ObservedObject private var catalogModel = CatalogModel()
    
    var body: some View {
        VStack {
            Text(String(data: catalogModel.leaderData, encoding: .utf8) ?? "No data yet")
                .padding()
            
            Button("Import file...") {
                showDocumentPicker.toggle()
            }
        }
        .sheet(isPresented: self.$showDocumentPicker) {
            DocumentPicker(callback : { urls in
                guard let pickedUrl = urls?.first else { return }
                catalogModel.open(url: pickedUrl)
            })

        }
        
    }
}

struct ContentView_Previews: PreviewProvider {
    
    static var previews: some View {
        ContentView()
    }
}

//
//  NewMessageView.swift
//  chatapp2
//
//  Created by TANMOY ROY on 11/03/24.
//

import SwiftUI
import SDWebImageSwiftUI

class createNewMessageViewModel: ObservableObject {
    
    @Published var users = [ChatUser]()
    @Published var errorMessage = ""
    
    init(){
        fetchAllUsers()
    }
    private func fetchAllUsers(){
        FirebaseManager.shared.firestore.collection("users")
            .getDocuments{documentssnapshot, error in
                if let error = error{
                    self.errorMessage = "Failed to fetch users \(error)"
                    print("failed to fetch users \(error)")
                    return
                }
                
                documentssnapshot?.documents.forEach({ snapshot in
                    let data = snapshot.data()
                    let user = ChatUser(data: data)
                    if user.uid != FirebaseManager.shared.auth.currentUser?.uid{
                        self.users.append(.init(data: data))
                    }
                    
                })
                
                //self.errorMessage = "Fetched users successfully"
            }
        
    }
}

struct CreateNewMessageView: View {
    
    let didSelectNewUser: (ChatUser) -> ()
    
    //used for cancle button
    @Environment(\.presentationMode) var presentationMode
    
    @ObservedObject var vm = createNewMessageViewModel()
    
    var body: some View {
        NavigationView{
            ScrollView{
                Spacer()
                ForEach(vm.users){user in
                    Button{
                        presentationMode.wrappedValue.dismiss()
                        didSelectNewUser(user)
                    }label: {
                        HStack{
                            WebImage(url: URL(string: user.profileImageUrl))
                                .resizable()
                                .scaledToFill()
                                .frame(width: 50, height: 50)
                                .clipped()
                                .cornerRadius(50)
                                .overlay(RoundedRectangle(cornerRadius: 50)
                                    .stroke(Color.black,lineWidth: 1)
                                )
                            Text(user.email)
                                .foregroundColor(Color.black)
                            Spacer()
                        }.padding(.horizontal)
                    }
                    Divider()
                        .padding(.vertical, 8)
                    
                    
                }
            }.navigationTitle("New Message")
                .toolbar{
                    ToolbarItemGroup(placement: .navigationBarLeading){
                        Button{
                            presentationMode
                                .wrappedValue
                                .dismiss()
                        }label: {
                            Text("Cancle")
                        }
                    }
                }
        }
    }
}

#Preview {
    //CreateNewMessageView()
    MainMessagesView()
}

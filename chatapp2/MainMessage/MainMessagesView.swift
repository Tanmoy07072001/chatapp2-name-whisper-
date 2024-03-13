//
//  MainMessagesView.swift
//  chatapp2
//
//  Created by TANMOY ROY on 11/03/24.
//

import SwiftUI
import SDWebImageSwiftUI
import Firebase

struct RecentMessage: Identifiable {
    var id: String { documentId }
    
    let documentId: String
    let text, email: String
    let fromId, toId: String
    let profileImageUrl: String
    let timestamp: Timestamp
    var chatUser: ChatUser?
    
    init(documentId: String, data: [String: Any]) {
        self.documentId = documentId
        self.text = data["text"] as! String
        self.fromId = data["fromId"] as! String
        self.toId = data["toId"] as! String
        self.profileImageUrl = data["profileImageUrl"] as! String
        self.email = data["email"] as! String
        self.timestamp = data["timestamp"] as! Timestamp
    }
}


class MainMessagesViewModel: ObservableObject {
    
    @Published var errorMessage = ""
    @Published var chatUser: ChatUser?
    
    
    init() {
        DispatchQueue.main.async{
            self.isUserCurrentlyLoggedOut =
                FirebaseManager.shared.auth.currentUser?.uid == nil
        }
        
        fetchCurrentUser()
        
        fetchRecentMessages()
    }
    
    @Published var recentMessages = [RecentMessage]()
    
    private func fetchRecentMessages(){
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else{return}
        
        FirebaseManager.shared.firestore
            .collection("recent_messages")
            .document(uid)
            .collection("messages")
            .order(by: "timestamp")
            .addSnapshotListener { querySnapshot, error in
                if let error = error{
                    self.errorMessage = "Failed to listen for recent messages \(error)"
                    print(error)
                    return
                }
                
                querySnapshot?.documentChanges.forEach({ change in
                    let docId = change.document.documentID
                    
                    if let index = self.recentMessages.firstIndex(where: { rm in
                        return rm.documentId == docId
                    }){
                        self.recentMessages.remove(at: index)
                    }
                    
                    self.recentMessages.insert(.init(documentId: docId, data: change.document.data()),at: 0)
                        
                })
            }
    }
    private func fetchUser(for userId: String, completion: @escaping (ChatUser?) -> Void) {
            FirebaseManager.shared.firestore.collection("users").document(userId).getDocument { snapshot, error in
                if let error = error {
                    print("Failed to fetch user:", error)
                    completion(nil)
                    return
                }
                
                guard let data = snapshot?.data() else {
                    completion(nil)
                    return
                }
                
                let user = ChatUser(data: data)
                completion(user)
            }
        }
    
    func fetchCurrentUser() {
        
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else {
            self.errorMessage = "Could not find firebase uid"
            return
        }
        
        
        FirebaseManager.shared.firestore.collection("users").document(uid).getDocument { snapshot, error in
            if let error = error {
                self.errorMessage = "Failed to fetch current user: \(error)"
                print("Failed to fetch current user:", error)
                return
            }
            

            
            guard let data = snapshot?.data() else {
                self.errorMessage = "No data found"
                return
                
            }
            
            self.chatUser = .init(data: data)

            
        }
    }
    
    //handling signout
    @Published var isUserCurrentlyLoggedOut = false
    func handleSignOut(){
        isUserCurrentlyLoggedOut.toggle()
        try? FirebaseManager.shared.auth.signOut()
    }
    
}
struct MainMessagesView: View {
    
    @State var shouldShowLogOutOptions = false
    @State var shouldNavigateToChatLogView = false
    
    @ObservedObject private var vm = MainMessagesViewModel()
    
    var body: some View {
        NavigationView {
            
            VStack {
                
                customNavBar
                messagesView
                
                NavigationLink("",isActive: $shouldNavigateToChatLogView){
                    chatLogView(chatUser: self.chatuser)
                }
            }
            .overlay(
                newMessageButton, alignment: .bottom)
            .navigationBarHidden(true)
        }
    }

    
    //custom navbar
    
    private var customNavBar: some View {
        HStack(spacing: 16) {
            
            if let imageUrl = URL(string: vm.chatUser?.profileImageUrl ?? "") {
                AsyncImage(url: imageUrl) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 50, height: 50)
                        .clipped()
                        .cornerRadius(50)
                        .overlay(RoundedRectangle(cornerRadius: 44)
                                    .stroke(Color(.label), lineWidth: 1)
                        )
                        .shadow(radius: 5)
                } placeholder: {
                    // Placeholder while loading
                    Image(systemName: "person.fill")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 50, height: 50)
                        .clipped()
                        .cornerRadius(50)
                        .overlay(RoundedRectangle(cornerRadius: 44)
                                    .stroke(Color(.label), lineWidth: 1)
                        )
                        .shadow(radius: 5)
                }
            } else {
                // Placeholder for when URL is invalid or empty
                Image(systemName: "person.fill")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipped()
                    .cornerRadius(50)
                    .overlay(RoundedRectangle(cornerRadius: 44)
                                .stroke(Color(.label), lineWidth: 1)
                    )
                    .shadow(radius: 5)
            }
            
            
            VStack(alignment: .leading, spacing: 4) {
                if let email = vm.chatUser?.email.replacingOccurrences(of: "@gmail.com", with: "") {
                    Text(email)
                        .font(.system(size: 24, weight: .semibold))
                }
                
                HStack {
                    Circle()
                        .foregroundColor(.green)
                        .frame(width: 12, height: 12)
                    Text("online")
                        .font(.system(size: 12))
                        .foregroundColor(Color.green)
                }
                
            }
            
            Spacer()
            Button {
                shouldShowLogOutOptions.toggle()
            } label: {
                Image(systemName: "gear")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Color.blue)
            }
        }
        .padding()
        .actionSheet(isPresented: $shouldShowLogOutOptions) {
            .init(title: Text("Settings"), message: Text("What do you want to do?"), buttons: [
                .destructive(Text("Sign Out"), action: {
                    print("handle sign out")
                    vm.handleSignOut()
                }),
                .cancel()
            ])
        }
        .fullScreenCover(isPresented: $vm.isUserCurrentlyLoggedOut, onDismiss: nil){
            LoginView(didColpletLoginProcess: {
                self.vm.isUserCurrentlyLoggedOut = false
                self.vm.fetchCurrentUser()
            })
        }
    }

    private func timeAgoSinceDate(_ date: Date, currentDate: Date) -> String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.second, .minute, .hour, .day], from: date, to: currentDate)
        
        if let seconds = components.second, seconds < 60 {
            return "\(seconds)s ago"
        } else if let minutes = components.minute, minutes < 60 {
            return "\(minutes)m ago"
        } else if let hours = components.hour, hours < 24 {
            return "\(hours)h ago"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }


    
//    private var messagesView: some View {
//        ScrollView {
//            ForEach(vm.recentMessages) { recentMessage in
//                VStack {
//                    NavigationLink {
//                        Text("Destination")
//                    } label: {
//                        HStack(spacing: 16) {
//                            WebImage(url: URL(string: recentMessage.profileImageUrl))
//                                .resizable()
//                                .scaledToFill()
//                                .frame(width: 64, height: 64)
//                                .clipped()
//                                .cornerRadius(64)
//                                .overlay(RoundedRectangle(cornerRadius: 44)
//                                            .stroke(Color(.label), lineWidth: 1)
//                                )
//                            
//                            
//                            VStack(alignment: .leading, spacing: 8) {
//                                Text(recentMessage.email)
//                                    .font(.system(size: 16, weight: .bold))
//                                Text(recentMessage.text)
//                                    .font(.system(size: 14))
//                                    .foregroundColor(Color(.lightGray))
//                                    .multilineTextAlignment(.leading)
//                            }
//                            Spacer()
//                            
//                            Text(timeAgoSinceDate(recentMessage.timestamp.dateValue(), currentDate: Date()))
//                                                        .font(.system(size: 14, weight: .semibold))
//                        }.foregroundColor(.black)
//                    }
//
//                
//                    Divider()
//                        .padding(.vertical, 8)
//                }.padding(.horizontal)
//                
//            }.padding(.bottom, 50)
//        }
//    }
    
    private var messagesView: some View {
        ScrollView {
            ForEach(vm.recentMessages) { recentMessage in
                VStack {
                    NavigationLink(destination: chatLogView(chatUser: recentMessage.chatUser)) {
                        HStack(spacing: 16) {
                            WebImage(url: URL(string: recentMessage.profileImageUrl))
                                .resizable()
                                .scaledToFill()
                                .frame(width: 64, height: 64)
                                .clipped()
                                .cornerRadius(64)
                                .overlay(RoundedRectangle(cornerRadius: 44)
                                            .stroke(Color(.label), lineWidth: 1)
                                )
                            
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text(recentMessage.email)
                                    .font(.system(size: 16, weight: .bold))
                                Text(recentMessage.text)
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(.lightGray))
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer()
                            
                            Text(timeAgoSinceDate(recentMessage.timestamp.dateValue(), currentDate: Date()))
                                .font(.system(size: 14, weight: .semibold))
                        }.foregroundColor(.black)
                    }

                
                    Divider()
                        .padding(.vertical, 8)
                }.padding(.horizontal)
                
            }.padding(.bottom, 50)
        }
    }

    
    //new message screen
    @State var shouldShowNewMessageScreen = false
    
    private var newMessageButton: some View {
        Button {
            shouldShowNewMessageScreen.toggle()
        } label: {
            HStack {
                Spacer()
                Text("+ New Message")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
            }
            .foregroundColor(.white)
            .padding(.vertical)
                .background(Color.blue)
                .cornerRadius(32)
                .padding(.horizontal)
                .shadow(radius: 15)
        }
        .fullScreenCover(isPresented: $shouldShowNewMessageScreen, onDismiss: nil){
            CreateNewMessageView(didSelectNewUser: {user in
                print(user.email)
                self.shouldNavigateToChatLogView.toggle()
                self.chatuser = user
            })
        }
    }
    @State var chatuser: ChatUser?
}


#Preview {
    //MainMessagesView().preferredColorScheme(.dark)
    
    MainMessagesView()
}

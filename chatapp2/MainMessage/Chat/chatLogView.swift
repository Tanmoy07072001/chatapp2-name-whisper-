//
//  ChatLogView.swift
//  chatapp2
//
//  Created by TANMOY ROY on 12/03/24.
//

import SwiftUI
import Firebase


struct firebaseConstants{
    
    static let fromId = "fromId"
    static let toId = "toId"
    static let text = "text"
    static let timestamp = "timestamp"
    static let profileImageUrl = "profileImageUrl"
    static let email = "email" 
    
}
struct ChatMessage: Identifiable {
    
    var id: String { documentId }
    
    let documentId: String
    let fromId ,toId ,text: String
    
    init(documentId: String,data: [String: Any]){
        self.documentId = documentId
        self.fromId = data[firebaseConstants.fromId] as! String
        self.toId = data[firebaseConstants.toId] as! String
        self.text = data[firebaseConstants.text] as! String
    }
}

class chatLogViewModel: ObservableObject {
    
    @Published var chatText = ""
    @Published var errorMessage = ""
    @Published var chatMessages = [ChatMessage]()
    
    let chatUser: ChatUser?
    
    init(chatUser: ChatUser?){
        self.chatUser = chatUser
        fetchMessages()
    }
    
    private func fetchMessages(){
        guard let fromId = FirebaseManager.shared.auth.currentUser?.uid else { return }
        guard let toId = chatUser?.uid else { return }
        FirebaseManager.shared.firestore
            .collection("messages")
            .document(fromId)
            .collection(toId)
            .order(by: "timestamp")
            .addSnapshotListener { querySnapshot, error in
                if let error = error {
                    self.errorMessage = "failed to listen for messsages : \(error)"
                    print(error)
                    return
                }
                
                querySnapshot?.documentChanges.forEach({ change in
                    if change.type == .added {
                        let data = change.document.data()
                        self.chatMessages.append(.init(documentId: change.document.documentID, data: data))
                    }
                })
                
                DispatchQueue.main.async {
                    self.count += 1
                }
                
            }
    }
    
    func handleSend(){
        print(chatText)
        guard let fromId = FirebaseManager.shared.auth.currentUser?.uid else { return }
        
        guard let toId = chatUser?.uid else { return }
        
        let document = FirebaseManager.shared.firestore
                        .collection("messages")
                        .document(fromId)
                        .collection(toId)
                        .document()
        
        let messageData = [firebaseConstants.fromId : fromId , firebaseConstants.toId : toId , firebaseConstants.text : self.chatText, "timestamp":Timestamp()]as [String: Any]
        
        document.setData(messageData) { error in
            if let error = error {
                print(error)
                self.errorMessage = "Failed to save message onto Firestore\(error)"
                return
            }
            print("successfully saved current user sending message ")
            
            self.persistRecentMessage()
            
            self.chatText = ""
            self.count += 1
        }
        let recipientMessageDocument = FirebaseManager.shared.firestore
                        .collection("messages")
                        .document(toId)
                        .collection(fromId)
                        .document()
        recipientMessageDocument.setData(messageData) { error in
            if let error = error {
                print(error)
                self.errorMessage = "Failed to save message onto Firestore\(error)"
                return
            }
            print("recipiemt saved message as well")
        }
    }
    
    private func persistRecentMessage () {
        
        guard let chatUser = chatUser else{ return }
        
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else{ return }
        guard let toId = self.chatUser?.uid else{ return }
        
        let document = FirebaseManager.shared.firestore
            .collection("recent_messages")
            .document(uid)
            .collection("messages")
            .document(toId)
        
        let data = [
            firebaseConstants.timestamp: Timestamp(),
            firebaseConstants.text : self.chatText,
            firebaseConstants.fromId : uid,
            firebaseConstants.toId: toId,
            firebaseConstants.profileImageUrl: chatUser.profileImageUrl,
            firebaseConstants.email: chatUser.email
        ] as [String: Any]
        
        document.setData(data) { error in
            if let error = error {
                self.errorMessage = "failed to save recent Message \(error)"
                print("failed to save recent Message \(error)")
                return
            }
        }
    }
    
    
    @Published var count = 0
}
struct chatLogView: View {
    
    let chatUser: ChatUser?
    
    init(chatUser: ChatUser?){
        self.chatUser = chatUser
        self.vm = .init(chatUser: chatUser)
    }
    
    @ObservedObject var vm: chatLogViewModel
    
    var body: some View {
        ZStack {
            messagesView
            Text(vm.errorMessage)
            VStack {
                Spacer()
                chatBottomBar
                    .background(Color.white)
                
            }
            .navigationTitle(chatUser?.email ?? "")
        .navigationBarTitleDisplayMode(.inline)
//        .navigationBarItems(trailing: Button(action: {
//            vm.count += 1
//        },label: {
//            Text("Count : \(vm.count)")
//        }))
        }
    }
    
    static let emptyScrollToString = "Empty"
    
    private var messagesView: some View{
        ScrollView{
            
            ScrollViewReader { scrollViewProxy in
                VStack{
                    
                    ForEach(vm.chatMessages){message in
                        
                        MessageView(message: message)
                        
                    }
                    HStack{ Spacer() }
                        .id(Self.emptyScrollToString)
                    
                }
                .onReceive(vm.$count, perform: { _ in
                    withAnimation(.easeOut(duration: 0.5)) {
                        scrollViewProxy.scrollTo(Self.emptyScrollToString, anchor: .bottom)
                    }
                })
                
            }
            
            
        }.padding(.bottom,65)
    }
    
    private var chatBottomBar: some View {
        HStack{
            Image(systemName: "photo.badge.plus")
                .font(.system(size: 24))
            Spacer()
            TextField("Description", text: $vm.chatText)
            Button{
                vm.handleSend()
            }label: {
                Image(systemName: "paperplane").font(.system(size: 24))
            }.padding(.horizontal)
                .padding(.vertical,3)
        }.padding(.horizontal)
            .padding(.vertical,8)
    }
}

struct MessageView: View {
    
    let message: ChatMessage
    
    var body: some View {
        VStack{
            if message.fromId == FirebaseManager.shared.auth.currentUser?.uid{
                HStack {
                    Spacer()
                    HStack {
                        Text(message.text)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(20)
                }
            }
            else{
                HStack {
                    HStack {
                        Text(message.text)
                            .foregroundColor(.black)
                    }
                    .padding()
                    .background(Color("Gray"))
                    .cornerRadius(20)
                    Spacer()
                }
            }
        }.padding(.horizontal)
            .padding(.top,8)
    }
}

#Preview {

    MainMessagesView()
    
}

//
//  ContentView.swift
//  chatapp2
//
//  Created by TANMOY ROY on 10/03/24.
//

import SwiftUI
import RiveRuntime
import Firebase
import FirebaseStorage



struct LoginView: View {
    
    let didColpletLoginProcess: () -> ()
    
    @State private var isLoginMode = true
    @State private var email = ""
    @State private var password = ""
    @State private var shouldShowImagePicker = false
    
    
    
    var body: some View {
        NavigationView{
            ZStack {
                
                //background animation
                RiveViewModel(fileName: "shapes").view()
                    .ignoresSafeArea()
                    .blur(radius: 40)
                    .background(Image("Spline").blur(radius: 50)
                    .offset(x: 200, y: 100))
                
                
                ScrollView{
                    VStack(spacing: 16){
                        Picker(selection: $isLoginMode,label: Text("picker here")) {
                            
                            Text("Login").tag(true)
                            
                            Text("Create account").tag(false)
                            
                        }.pickerStyle(.segmented).padding()
                        
                        if !isLoginMode {
                            Button{
                                shouldShowImagePicker.toggle()
                            }label: {
                                
                                VStack{
                                    
                                    if let image = self.image{
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 128,height: 128)
                                            .cornerRadius(64)
                                            
                                    }
                                    else{
                                        Image(systemName: "person")
                                            .font(.system(size: 64))
                                            .padding()
                                            .foregroundColor(Color(.label))
                                    }
                                }
                                .overlay(RoundedRectangle(cornerRadius: 64).stroke(Color.green,lineWidth: 2))
                            }
                        }
                        Group{
                            TextField("email",text: $email).padding()
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .background(Color("Gray"))
                                .cornerRadius(20)
                                .opacity(0.7)
                            SecureField("password" , text: $password).padding()
                                .autocapitalization(.none)
                                .background(Color("Gray"))
                                .cornerRadius(20)
                                .opacity(0.7)
                        }.padding(.horizontal)

                        
                        HStack {
                            Button{
                                handleAction()
                            }label: {
                                HStack {
                                    Spacer()
                                    Text(isLoginMode ? "Login" : "Create Account")
                                        .foregroundColor(.white)
                                        .padding(10)
                                    Spacer()
                                }.background(Color.blue)
                                    .cornerRadius(30)
                                    .opacity(0.8)
                        }
                            
                        }.padding()
                        
                        Text(self.loginStatusMessage).foregroundColor(.red)
                    }
                    .navigationTitle(isLoginMode ? "Login :" : "Create account : ")
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .fullScreenCover(isPresented: $shouldShowImagePicker, onDismiss: nil){
            ImagePicker(image: $image)
        }
    }
    
    @State var image: UIImage?
    
    
    private func handleAction(){
        if isLoginMode {
            loginUser()
        }else{
            createNewAccount()
        }
    }
    
    
    
    @State var loginStatusMessage = ""
    
    //login user ar Firebase
    private func loginUser(){
        FirebaseManager.shared.auth.signIn(withEmail: email, password: password) { result, err in
            if let err = err {
                print("Failed to login user : " ,err)
                self.loginStatusMessage = "Failed to login user : \(err)"
                return
            }
            print("Successfully logged in as  user : \(result?.user.uid)")
            self.loginStatusMessage = "Successfully logged in as user \(result?.user.uid)"
            self.didColpletLoginProcess()
        }
    }
    
    //create new account at Firebase
    private func createNewAccount(){
        
        if self.image == nil {
            self.loginStatusMessage = "you must select an avator image !"
            return
        }
        
        FirebaseManager.shared.auth.createUser(withEmail: email, password: password) { result, err in
            if let err = err {
                print("Failed to create user : " ,err)
                self.loginStatusMessage = "Failed to create user : \(err)"
                return
            }
            print("Successfully created user : \(result?.user.uid)")
            self.loginStatusMessage = "Successfully created user \(result?.user.uid)"
            
            self.persistImageToStorage()
        }
    }
    
    private func persistImageToStorage(){
        let filename = UUID().uuidString
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else{return}
        let ref = FirebaseManager.shared.storage.reference(withPath: uid)
        guard let imagedata = self.image?.jpegData(compressionQuality: 0.5)else{return}
        ref.putData(imagedata, metadata: nil ) { metadata, err in
            if let err = err {
                self.loginStatusMessage = "Failed to push image to storage : \(err)"
                return
            }
            
            ref.downloadURL { url , err in
                if let err = err {
                    self.loginStatusMessage = "Failed to retrieve download url : \(err)"
                    return
                }
                
                self.loginStatusMessage = "successfully stored image with url : \(url?.absoluteString)"
                print(url?.absoluteString)
                
                guard let url = url else { return }
                self.storeUserInformation(imageProfileUrl: url)
                
            }
        }
    }
    
    
    
    private func storeUserInformation(imageProfileUrl: URL) {
        
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else { return }
        let userData = ["email": self.email, "uid": uid, "profileImageUrl": imageProfileUrl.absoluteString]
        
        FirebaseManager.shared.firestore.collection("users")
            .document(uid).setData(userData) { err in
                if let err = err {
                    print(err)
                    self.loginStatusMessage = "\(err)"
                    return
                }
                
                print("Success")
                self.didColpletLoginProcess()
            }
        
    }
    
    
    
}

#Preview {
    LoginView(didColpletLoginProcess: {
        //MainMessagesView()
    })
//    MainMessagesView()
}

class AppUser{
  final String uid;
  final String email;
  final String role;
  AppUser({
    required this.uid,
    required this.email,
    required this.role,
  });

  //convert app user->json
  Map<String, dynamic> toJson(){
    return{
      'uid':uid,
      'email':email,
      'role':role,
    };
  }
  //convert json->app user
  factory AppUser.fromJson(Map<String,dynamic>jsonUser){
    return AppUser(
      uid:jsonUser['uid'],
      email:jsonUser['email'],
      role:jsonUser['role'],
    );

  }
}
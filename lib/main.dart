//import 'dart:html';

import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
//import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
//import 'package:flutter/camera.dart';
import 'package:http_parser/http_parser.dart';
//TODO: make right icons for the different hdpi
String _hostName='';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  final firstCamera = cameras.first;

  runApp(MyApp(appCamera: firstCamera));
}



class MyApp extends StatelessWidget {
  final CameraDescription appCamera;


  const MyApp({Key key, this.appCamera}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WITS',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      initialRoute: '/',
      routes: {
        '/':(context)=>AuthorizationPage(),
        '/register': (context)=>RegistrationPage(),
        '/main': (context)=>MainPage(),
        '/shoot': (context)=>TakePicturePage(camera: appCamera),
        //'/send':(context) => DisplayPicturePage(),
      },
      //home: AuthorizationPage(),
    );
  }
}
class TakePicturePage extends StatefulWidget {
  final CameraDescription camera;

  const TakePicturePage({Key key, @required this.camera}) : super(key: key);

  @override
  State<StatefulWidget> createState() =>TakePicturePageState();

}

class TakePicturePageState extends State<TakePicturePage> {
  CameraController _controller;
  Future<void> _initializeControllerFuture;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(widget.camera, ResolutionPreset.medium,);
    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Take a picture'),),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState==ConnectionState.done) {
            return CameraPreview(_controller);
          } else {
            return Center(child: CircularProgressIndicator(),);
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.camera_alt),
        onPressed: () async {
          try {
            await _initializeControllerFuture;
            final image = await _controller.takePicture();
            //TODO: set a named route
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context)=>DisplayPicturePage(
                    imagePath: image?.path,
                  ),
              ),
            );
          } catch (e) {
            print(e);
          }
        },
      ),
    );
  }

}


Future<bool> postPicture(String token, String image, String location, String caption,String level) async {
  Map<String, String> headers = {
    "Accept": "application/json",
    "Authorization": "Token " + token
  }; // ignore this headers if there is no authentication

  var request = new http.MultipartRequest('POST', Uri.http(_hostName,'app/') )
    ..fields['location'] = location
    ..fields['caption'] = caption
    ..fields['level'] = level
    ..files.add(await http.MultipartFile.fromPath('image', image,contentType: new MediaType('image', 'jpeg')));
  request.headers.addAll(headers);
  var response = await request.send();
    print("Response status: ${response.statusCode}");
    response.stream.transform(utf8.decoder).listen((value) {
      print(value);

    });

  if(response.statusCode==201) {
      return true;
    } else {
      throw Exception('Failed opinion post to server ');
    }




/*
  final response = await http.post(
      Uri.http('10.0.2.2:8000','app/'),
      headers: <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'multipart/form-data',
        HttpHeaders.authorizationHeader: 'Token '+token,

      },
      body: jsonEncode(<String, String>{
        'image': image+';type=image/jpg',
        'location' : location,
        'caption': caption,
        'level' : level
      })
  );
  print("Response status: ${response.statusCode}");
  print("Response body: ${response.body}");

  if(response.statusCode==201) {
    return true;
  } else {
    throw Exception('Failed opinion post to server ');
  }*/
}

class DisplayPicturePage extends StatefulWidget {
  final String imagePath;


  const DisplayPicturePage({Key key, this.imagePath}) : super(key: key);

  @override
  State<StatefulWidget> createState() => DisplayPicturePageState(imagePath);

}


class DisplayPicturePageState extends State<DisplayPicturePage> {
  final String imagePath;

  final _authFormKey = GlobalKey<FormState>();
  //TODO: Take location from db
  final locationController = TextEditingController();
  final captionController = TextEditingController();

  int level=0;
  String _token='';
  Future<bool> _futurePostPicture;
  static const List<String> LEVEL=['L','M','H'];

  DisplayPicturePageState(this.imagePath);

  @override
  void initState(){
    super.initState();

    _loadToken().then( (value) {
      _token = value;
      setState(() {});
    });

    print("_Token in init func : ${_token}");
  }


  @override
  void dispose() {
    locationController.dispose();
    captionController.dispose();
    super.dispose();
  }

  _loadToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

      String token = (prefs.getString('token')??'');
      print("Token in load func : ${token}");
      return token;
  }


  List<Widget> _createLevelStars() {
    List<Widget> list =  [];
    for (var i=0;i<3;i++){
      list.add(
          GestureDetector(
            child: Icon(
                    Icons.ac_unit,
                    color: level<i ? Colors.blueGrey: Colors.blue,
                    ),
            onTap: () {
              setState(() {
                level=i;
              });
            }
          ),
      ) ;
    }
    return list;
  }

  Widget _takeDescription(String imagePath) {
    return SingleChildScrollView(
      child: Form(
        key: _authFormKey,
        child: Column(
          children: [
            Center(child: Image.file(File(imagePath))),
            Container(
              child: Column(
                children: [
                  Align(
                      child: Text('Snow level'),
                      alignment: Alignment.topLeft ,),
                  Row(
                    children: _createLevelStars()
                  ),
                ],
              ),
              decoration: BoxDecoration(
                border: Border.all(),
                borderRadius: BorderRadius.all(Radius.circular(10.0)),

              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextFormField(
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Location',),
                validator: (value) {
                  if (value.isEmpty) {
                    return 'Must be some text';
                  }
                  return null;
                },
                controller: locationController,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextFormField(

                decoration: InputDecoration(
                    border: OutlineInputBorder(), labelText: 'Caption'),
                validator: (value) {
                  if (value.isEmpty) {
                    return 'Must be some text';
                  }
                  return null;
                },
                controller: captionController,
              ),
            ),
            Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                    height: 50.0,
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        //_loadToken();
                        print("Token is: ${_token}");


                        setState(() {
                          if (_authFormKey.currentState.validate()) {
                            print("_token ${_token}");
                            print("imagePath ${imagePath}");
                            print("locationController.text ${locationController.text}");
                            print("captionController.text ${captionController.text}");
                            print("LEVEL[level] ${ LEVEL[level]}");


                            _futurePostPicture=postPicture(_token, imagePath, locationController.text,
                                captionController.text, LEVEL[level]);

                            //Navigator.pushNamed(context, '/main');
                          }
                        });

                      },
                      child: Text('Public',textScaleFactor: 1.3,),
                    )))


          ],
        ),
      ),

    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Display the Picture'),),
      body: (_futurePostPicture==null)
        ? _takeDescription(imagePath)
        : FutureBuilder<bool>(
          future: _futurePostPicture,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Navigator.pushNamed(context, '/main');
              });
              return
                Center(

                  child: Column(
                    children: [
                      Icon(
                        Icons.check_circle, color: Colors.blue, size: 150.0,),
                      Text('Post successfully sent'),
                    ],
                  ),
                );
            } else if (snapshot.hasError) {
              return Text("${snapshot.error}");
            }


            return Center(child: CircularProgressIndicator());
          }
      )
    );
  }

}

class MainPage extends StatefulWidget {
  @override
  _MainPageState createState() => _MainPageState();
}

Future<List<Opinion>> fetchOpinions(http.Client client) async {
  //final response = await client.get(Uri.parse('http://10.0.0.2:8000/app/'));
  final response = await http.get(
      Uri.http(_hostName,'app/'));
  print("Response status: ${response.statusCode}");
  print("Response body: ${response.body}");

  if(response.statusCode==200) {
    return compute(parseOpinions, response.body);
  } else {
    throw Exception('Failed app request');
  }


}

class Opinion {
  final int id;
  final String created;
  final String location;
  final String caption;
  final String imgUrl;
  final String owner;
  final String level;


  Opinion({this.id, this.created,this.location, this.caption, this.imgUrl, this.owner, this.level});

  factory Opinion.fromJson(Map<String, dynamic> json) {
    return Opinion(
        id: json['id'] as int,
        created: json['created'] as String,
        location: json['location'] as String,
        caption: json['caption'] as String,
        imgUrl: json['image'] as String,
        owner: json['owner'] as String,
        level: json['level'] as String,
    );
  }

}

List<Opinion> parseOpinions(String responseBody) {
  final parsed = jsonDecode(responseBody).cast<Map<String, dynamic>>();

  return parsed.map<Opinion>((json)=>Opinion.fromJson(json)).toList();
}

enum Pages{
  HOME,
  SEARCH,
  NEW,
  FAVORITE,
  ACCOUNT,
}

class _MainPageState extends State<MainPage> {

  Pages _selectedPage = Pages.HOME;

  void _onPageItemTapped(int index) {
    setState(() {
      _selectedPage = Pages.values[index];
    });
  }

  Widget _listOpinionsPage(BuildContext context ) {
    return FutureBuilder<List<Opinion>>(
      future: fetchOpinions(http.Client()),
      builder: (context, snapshot) {
        if (snapshot.hasError) print (snapshot.error);

        return snapshot.hasData
            ? OpinionList(opinions : snapshot.data)
            : Center(child: CircularProgressIndicator(),);
      },
    );
  }


  Widget _pageAtItem(BuildContext context, Pages index) {
    switch (index){
      case Pages.HOME:
        return _listOpinionsPage(context);
        break;
      case Pages.SEARCH:
        return Text("Search");
        break;
      //TODO: is realy right?
      case Pages.NEW:
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushNamed(context, '/shoot');
        });
        return Center(child: Icon(Icons.photo_camera));
        break;
      case Pages.FAVORITE:
        return Text("Favorite");
        break;
      case Pages.ACCOUNT:
        return Text("Account");
        break;
    }

  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
        appBar: AppBar(
          leading: Icon(Icons.image),
          title: Text('WITS'),
        ),
        body:
        //ListView( padding: const EdgeInsets.all(8),  children: [post],  )
          _pageAtItem(context, _selectedPage),
        bottomNavigationBar: BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
                icon: Icon(Icons.home),
                label: 'Home',
            ),
            BottomNavigationBarItem(
                icon: Icon(Icons.search),
                label: 'Search',
            ),
            BottomNavigationBarItem(
                icon: Icon(Icons.add_a_photo),
                label: 'New',
            ),
            BottomNavigationBarItem(
                icon: Icon(Icons.favorite),
                label: 'Favorite',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_circle),
              label: 'Account',
            ),
          ],
          currentIndex: _selectedPage.index,
          selectedItemColor: Colors.blue,
          unselectedItemColor: Colors.grey,
          onTap: _onPageItemTapped,
          type: BottomNavigationBarType.shifting,
        ),
    );
  }
}

class OpinionList extends StatelessWidget {
  final List<Opinion> opinions;

  const OpinionList({Key key, this.opinions}) : super(key: key);

  Widget _image (String url) {
    return Container(
      padding: EdgeInsets.all(10.0),
      child: Image.network(url, width: 200.0, height: 200.0,), //Image opinions[index].imgUrl
      //Icon(Icons.add_a_photo, size: 200.0,)
    );
  }

  Widget _dateLocation(String date, String location) {
   return
     Container(
        padding: EdgeInsets.all(10.0),
        child:
          Row(
            children: [
              Expanded(
                child: Text(                                      //Date opinions[index].created,
                            date,
                            textAlign: TextAlign.left,
                            )
              ),
              Expanded(
                child: Text(                                 //Location opinions[index].location
                            location ,
                            textAlign: TextAlign.right))
                      ],
             )
    );
   }

   Widget _level (String level) {
    return
      Padding(
        padding: const EdgeInsets.all(10.0),
        child: Row(
         children: [
           Text(level),                          //Temporary Level opinions[index].level
           Row(
             children: [
               Icon(
                 Icons.ac_unit,
                 color: Colors.blue,
               ),
               Icon(
                 Icons.ac_unit,
                 color: Colors.blue,
               ),
               Icon(
                 Icons.ac_unit,
                 color: Colors.blueGrey,
               )
             ],
           )
         ],
     ),
      );
   }

  Widget _likes () {
    return  Row(children: [
      Container(
        width: 50.0,
        padding: EdgeInsets.all(5.0),
        alignment: Alignment.centerLeft,
        child: Icon(Icons.ac_unit_rounded),
      ),
      Container(
        padding: EdgeInsets.all(5.0),
        child: Icon(Icons.favorite_border),
      ),
      Container(
        padding: EdgeInsets.all(5.0),
        child: Icon(Icons.comment),
      ),
      Container(
        padding: EdgeInsets.all(5.0),
        child: Icon(Icons.send),
      ),
      Expanded(
          child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                child: Icon(Icons.bookmark_border),
              )))
    ]);
  }

  Widget _comments(String owner, String caption) {
    return Container(
        padding: EdgeInsets.all(10.0),
        child: Column(
          children: [
            Row(
              children: [
                Text(owner,                         //owner opinions[index].owner
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text('  '),
                Text(caption)                       //caption opinions[index].caption
              ],
            ),
            Align(
                alignment: Alignment.centerLeft,
                child: Text('Показать комментарии',
                    style: TextStyle(color: Colors.grey))),
            Row(children: [
              Text('Dubrovsky', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('  '),
              Text('Да х.з.')
            ])
          ],
        ));
  }

  Widget _post ( List<Opinion> opinions, int index) {
    return Container(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _image(opinions[index].imgUrl),
          _dateLocation(opinions[index].created, opinions[index].location),
          _level(opinions[index].level),
          _likes(),
          _comments(opinions[index].owner, opinions[index].caption)
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: opinions.length,
      itemBuilder: (context, index) {
        return //Center(child: Text('nothing'),);
          _post(opinions, index);

      }
    );

  }




}

class AuthorizationPage extends StatefulWidget {
  @override
  _AuthorizationPageState createState() => _AuthorizationPageState();
}

Future<UserToken> getUserToken(String name, String password) async {
  final response = await http.post(
      Uri.http(_hostName,'auth/'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, String>{
        'username': name ,
        'password' : password,
      })
  );
  print("Response status: ${response.statusCode}");
  print("Response body: ${response.body}");

  if(response.statusCode==200) {
    return UserToken.fromJson(jsonDecode(response.body));
  } else {
    throw Exception('Failed authorization');
  }
}

class UserToken {
  final String token;

  UserToken({this.token});

  factory UserToken.fromJson(Map<String, dynamic> json) {
    return UserToken(
        token: json['token']
    );
  }

}

class _AuthorizationPageState extends State<AuthorizationPage> {

  double _textScale=1.3;
  final _authFormKey = GlobalKey<FormState>();
  final userNameController = TextEditingController();
  final passwordController = TextEditingController();
  final hostNameController = TextEditingController();

  Future<UserToken> _futureUserToken;

  String _token = '';

/*
  void _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _token = (prefs.getString('token')??'');
    });

  }*/

  _setToken(String token) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('token', token);
  }

  _setName(String name) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('username', name);
  }

  @override
  void dispose() {
    userNameController.dispose();
    passwordController.dispose();
    hostNameController.dispose();
    super.dispose();
  }




  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Авторизация'),
      ),
      body: SingleChildScrollView(

        child: (_futureUserToken==null)
        ? Form(
          key: _authFormKey,
          child: Column(

              children: [
                Icon(
                  Icons.image_outlined,
                  size: 100.0,
                ),
                Container(
                  padding: const EdgeInsets.all(32),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Авторизация',
                          style: TextStyle(fontWeight: FontWeight.bold),
                          textScaleFactor: _textScale,
                        ),
                      ),
                      GestureDetector(
                        child: Text('Регистрация',textScaleFactor: _textScale),
                        onTap: () {
                          Navigator.pushNamed(context, '/register');
                        },
                      )
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextFormField(
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Хост',),
                    validator: (value) {
                      if (value.isEmpty) {
                        return 'Must be some text';
                      }
                      return null;
                    },
                    controller: hostNameController,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextFormField(
                    decoration: InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Пользователь',),
                    validator: (value) {
                      if (value.isEmpty) {
                        return 'Must be some text';
                      }
                      return null;
                    },
                    controller: userNameController,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextFormField(
                    obscureText: true,
                    decoration: InputDecoration(
                        border: OutlineInputBorder(), labelText: 'Пароль'),
                    validator: (value) {
                      if (value.isEmpty) {
                        return 'Must be some text';
                      }
                      return null;
                    },
                    controller: passwordController,
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text('Забыли пароль?',textScaleFactor: _textScale),
                  ),
                ),
                Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                        height: 50.0,
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {

                            setState(() {
                              if (_authFormKey.currentState.validate()) {
                                _hostName=hostNameController.text;
                                _futureUserToken=getUserToken(userNameController.text,
                                    passwordController.text);
                                //Navigator.pushNamed(context, '/main');
                              }
                            });

                          },
                          child: Text('Войти',textScaleFactor: _textScale,),
                        )))
            ]),
        )
        : FutureBuilder<UserToken>(
            future: _futureUserToken,
            builder: (context,snapshot){
              if(snapshot.hasData) {
                print("Get a token from server : ${snapshot.data.token}");
                _setToken(snapshot.data.token);
                _setName(userNameController.text);

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  //_loadToken();
                  //print("Get token from storage: ${_token}");
                  Navigator.pushNamed(context, '/main');
                });
                return
                  Center(

                    child: Column(
                      children: [
                        Icon(Icons.check_circle, color: Colors.blue,size: 150.0,),
                        Text('User successfully registered'),
                        Text(_token),
                      ],
                    ),
                  );
              } else if (snapshot.hasError){
                return Text("${snapshot.error}");
              }


              return Center(child: CircularProgressIndicator());
            }
        )
      ),
    );
  }
}

class RegistrationPage extends StatefulWidget {
  @override
  RegistrationPageState createState() {
    return RegistrationPageState();
  }
}

Future<MyUser> createUser(String name, String password, String email, String host) async {
  final response = await http.post(
    Uri.http(host,'register/'),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: jsonEncode(<String, String>{
      'username': name ,
      'password' : password,
      'email': email,
    })
  );
  print("Response status: ${response.statusCode}");
  print("Response body: ${response.body}");

  if(response.statusCode==201) {
    return MyUser.fromJson(jsonDecode(response.body));
  } else {
    throw Exception('Failed to create user.');
  }
}

class MyUser {
  final String username;
  final String email;

  MyUser({this.username, this.email});

  factory MyUser.fromJson(Map<String, dynamic> json) {
    return MyUser(
      username: json['username'],
      email: json['email']
    );
  }

}

class RegistrationPageState extends State<RegistrationPage> {
  final _regformKey = GlobalKey<FormState>();
  final userNameController = TextEditingController();
  final passwordController = TextEditingController();
  final emailController = TextEditingController();
  final hostNameController = TextEditingController();
  Future<MyUser> _futureMyUser;
  String _hostForRegistration;

  @override
  void dispose() {
    userNameController.dispose();
    passwordController.dispose();
    emailController.dispose();
    hostNameController.dispose();
    super.dispose();
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Text('Registration')),
        body: SingleChildScrollView(
          child: Container(
              //margin: const EdgeInsets.all(10),
              //padding: EdgeInsets.all(10),
              child: (_futureMyUser==null)
            ? Form(
                  key: _regformKey,
                  child:  Column(
                     // mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: <Widget>[
                        Icon(Icons.face, size: 150,),
                        Container(
                          padding: EdgeInsets.all(10),
                          child: TextFormField(
                            decoration: InputDecoration(
                                border: OutlineInputBorder(),
                                labelText: 'Хост}'),
                            validator: (value) {
                              if (value.isEmpty) {
                                return 'Must be some text';
                              }
                              return null;
                            },
                            controller: hostNameController,
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.all(10),
                          child: TextFormField(
                            decoration: InputDecoration(
                                border: OutlineInputBorder(),
                                labelText: 'Пользователь'),
                            validator: (value) {
                              if (value.isEmpty) {
                                return 'Must be some text';
                              }
                              return null;
                            },
                            controller: userNameController,
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.all(10),
                          child: TextFormField(
                            obscureText: true,
                            decoration: InputDecoration(
                                border: OutlineInputBorder(), labelText: 'Пароль'),
                            validator: (value) {
                              if (value.isEmpty) {
                                return 'Must be some text';
                              }
                              return null;
                            },
                            controller: passwordController,
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.all(10),
                          child: TextFormField(
                              obscureText: true,
                              decoration: InputDecoration(
                                  border: OutlineInputBorder(),
                                  labelText: 'Повторите пароль'),
                              validator: (value) {
                                if (value.isEmpty) {
                                  return 'Must be some text';
                                }
                                if (value != passwordController.text) {
                                  return 'Passwords not equal';
                                }
                                return null;
                              }),
                        ),
                        Container(
                          padding: EdgeInsets.all(10),
                          child: TextFormField(
                            decoration: InputDecoration(
                                border: OutlineInputBorder(), labelText: 'Email'),
                            validator: (value) {
                              if (!value.contains('@')) {
                                return 'Must be valid email address';
                              }
                              return null;
                            },
                            controller: emailController,
                          ),
                        ),
                        Container(
                            width: double.infinity,

                            padding: EdgeInsets.all(10),
                            child: ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    if (_regformKey.currentState.validate()) {
                                      _hostForRegistration = hostNameController.text;
                                      _futureMyUser=createUser(userNameController.text,
                                          passwordController.text,
                                          emailController.text, _hostForRegistration);
                                    }
                                  });
                                },
                                child: Text('Register'))
                        )
                      ],
                    ),
                  )
                  : FutureBuilder<MyUser>(
                  future: _futureMyUser,
                  builder: (context,snapshot){
                    if(snapshot.hasData) {
                      return Column(
                        children: [

                          Text("You successfully registered user ${snapshot.data.username},"
                              "we have send you an email to ${snapshot.data.email}, please follow the link"
                              "in it, to complete the registration",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              child: Text('Ok'))
                        ],

                      );
                    } else if (snapshot.hasError){
                      return Text("${snapshot.error}");
                    }
                    return CircularProgressIndicator();
                  }
                  )
          ),
        )
    );
  }
}

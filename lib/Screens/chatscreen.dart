import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:location/location.dart';
import 'package:trustique/Widgets/messagecard.dart';
import 'package:trustique/main.dart';
import 'package:trustique/models/chat_user.dart';
import 'package:trustique/api/api.dart';
import 'package:trustique/models/message.dart';
import 'package:url_launcher/url_launcher.dart';

class ChatScreen extends StatefulWidget {
  final ChatUser user;

  const ChatScreen({super.key, required this.user});

  @override
  State<ChatScreen> createState() => _chatscreenState();
}

class _chatscreenState extends State<ChatScreen> {
  List<Message> _list = [];
  Location? _pickedLocation;
  var _isGettingLocation = false;
  void _getcurrentlocation() async {
    Location location = Location();

    bool serviceEnabled;
    PermissionStatus permissionGranted;
    LocationData locationData;

    serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) {
        return;
      }
    }

    permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        return;
      }
    }
    setState(() {
      _isGettingLocation = true;
    });

    locationData = await location.getLocation();

    setState(() {
      _isGettingLocation = false;
    });
    if (_list.isEmpty) {
      //on first message (add user to my_user collection of chat user)
      APIs.sendFirstMessage(
          widget.user,
          'https://www.google.com/maps/@${locationData.longitude},${locationData.latitude}',
          Type.link);
    } else {
      //simply send message
      APIs.sendMessage(
          widget.user,
          'https://www.google.com/maps/@${locationData.longitude},${locationData.latitude}',
          Type.link);
    }
  }

  final _textController = TextEditingController();
  bool _isUploading = false;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          flexibleSpace: _appbar(),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
        backgroundColor: Theme.of(context).colorScheme.background,
        body: Column(children: [
          Expanded(
            child: StreamBuilder(
                stream: APIs.getallmessages(widget.user),
                builder: (context, snapshot) {
                  switch (snapshot.connectionState) {
                    case ConnectionState.waiting:
                    case ConnectionState.none:
                      return const Center(child: CircularProgressIndicator());

                    //if some or all data is loaded then show it
                    case ConnectionState.active:
                    case ConnectionState.done:
                      final data = snapshot.data?.docs;
                      //log('Data: ${jsonEncode(data![0].data())}');
                      _list = data
                              ?.map((e) => Message.fromJson(e.data()))
                              .toList() ??
                          [];
                      //final _list = ["hi", "hello"];
                      // _list.clear();
                      // _list.add(Message(
                      //     msg: "Hello ji namaste",
                      //     toid: APIs.user.uid,
                      //     read: 'asdsa',
                      //     type: Type.text,
                      //     fromid: '',
                      //     sent: 'asdsa'));
                      // _list.add(Message(
                      //     msg: "Hello",
                      //     toid: "dsadsa",
                      //     read: 'qewqwe',
                      //     type: Type.text,
                      //     fromid: APIs.user.uid,
                      //     sent: '12:00 A.M.'));
                      if (_list.isNotEmpty) {
                        return ListView.builder(
                            // padding: EdgeInsets.only(left: 1),
                            itemCount: _list.length,
                            physics: BouncingScrollPhysics(),
                            itemBuilder: (context, index) {
                              return MessageCard(message: _list[index]);
                            });
                      } else {
                        return SizedBox(
                          child: Center(
                            child: TextLiquidFill(
                              text: 'Say Hiii!!! 👋🏻',
                              waveDuration: Duration(seconds: 3),
                              waveColor:
                                  const Color.fromARGB(255, 255, 255, 255),
                              boxBackgroundColor:
                                  Theme.of(context).primaryColor,
                              textStyle: TextStyle(
                                fontSize: 30.0,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      }
                  }
                }),
          ),
          if (_isUploading)
            const Align(
                alignment: Alignment.centerRight,
                child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8, horizontal: 20),
                    child: CircularProgressIndicator(strokeWidth: 2))),
          _chatInput(),
        ]),
      ),
    );
  }

  Widget _appbar() {
    return InkWell(
      onTap: () {},
      child: Row(
        children: [
          IconButton(
            onPressed: () => {Navigator.pop(context)},
            icon: Icon(
              CupertinoIcons.back,
              color: Colors.black,
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(sz.height * .03),
            child: CachedNetworkImage(
              width: sz.height * .045,
              height: sz.height * .045,
              imageUrl: widget.user.image,
              errorWidget: (context, url, error) =>
                  const CircleAvatar(child: Icon(CupertinoIcons.person)),
            ),
          ),
          Padding(padding: EdgeInsets.only(right: 10)),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.user.name,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge!.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              SizedBox(
                height: 3,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chatInput() {
    return Padding(
      padding: EdgeInsets.symmetric(
          vertical: sz.height * 0.01, horizontal: sz.width * 0.025),
      child: Row(
        children: [
          Expanded(
            child: Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      style: TextStyle(
                        color: Colors.white,
                      ),
                      controller: _textController,
                      keyboardType: TextInputType.multiline,
                      maxLines: null,
                      decoration: InputDecoration(
                        hintText: "Type a message",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(50),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                      onPressed: () async {
                        final ImagePicker picker = ImagePicker();

                        // Picking multiple images
                        final List<XFile> images =
                            await picker.pickMultiImage(imageQuality: 70);

                        // uploading & sending image one by one
                        for (var i in images) {
                          log('Image Path: ${i.path}');
                          setState(() => _isUploading = true);
                          await APIs.sendChatImage(widget.user, File(i.path));
                          setState(() => _isUploading = false);
                        }
                      },
                      icon: Icon(
                        Icons.image,
                      )),
                  IconButton(
                      onPressed: _getcurrentlocation,
                      icon: Icon(
                        Icons.location_on,
                      )),
                ],
              ),
            ),
          ),
          MaterialButton(
            onPressed: () {
              if (_textController.text.isNotEmpty) {
                if (_list.isEmpty) {
                  //on first message (add user to my_user collection of chat user)
                  APIs.sendFirstMessage(
                      widget.user, _textController.text, Type.text);
                } else {
                  //simply send message
                  APIs.sendMessage(
                      widget.user, _textController.text, Type.text);
                }
                _textController.text = '';
              }
            },
            padding: EdgeInsets.only(top: 10, bottom: 10, right: 10, left: 10),
            shape: const CircleBorder(),
            color: Colors.black,
            minWidth: 1,
            child: const Icon(
              CupertinoIcons.paperplane,
              size: 20,
              color: Colors.white,
            ),
          )
        ],
      ),
    );
  }
}

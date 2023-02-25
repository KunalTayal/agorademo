import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:agora_rtm/agora_rtm.dart';
import 'package:demoagora1/message.dart';
import 'package:demoagora1/models/director_model.dart';
import 'package:demoagora1/models/stream.dart';
import 'package:demoagora1/models/user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../rtc_repo.dart';

final directorController =
    StateNotifierProvider.autoDispose<DirectorController, DirectorModel>((ref) {
  return DirectorController(ref.read);
});

class DirectorController extends StateNotifier<DirectorModel> {
  final Reader read;

  DirectorController(this.read) : super(DirectorModel());

  Future<void> _initialize() async {
    RtcEngine _engine = createAgoraRtcEngine();
    await _engine.initialize(const RtcEngineContext(
      appId: "33c15fb39160412e880f5891513aedd9",
      channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
    ));
    AgoraRtmClient? _client =
        await AgoraRtmClient.createInstance("33c15fb39160412e880f5891513aedd9");
    state = DirectorModel(engine: _engine, client: _client);
  }

  Future<void> joinCall({required String channelName, required int uid}) async {
    await _initialize();
    AgoraRtmChannel? _channel = await read(rtcRepoProvider)
        .joinCallAsDirector(state.engine!, state.client!, channelName, uid);
    state = state.copyWith(channel: _channel);
  }

  Future<void> leaveCall() async {
    state.channel?.leave();
    state.client?.logout();
    state.client?.destroy();
    state.engine?.leaveChannel();
  }

  Future<void> toggleUserAudio(
      {required int index, required bool muted}) async {
    if (muted) {
      state.channel!.sendMessage(AgoraRtmMessage.fromText(
          "unmute ${state.activeUsers.elementAt(index).uid}"));
    } else {
      state.channel!.sendMessage(AgoraRtmMessage.fromText(
          "mute ${state.activeUsers.elementAt(index).uid}"));
    }
  }

  Future<void> updateUserAudio({required int uid, required bool muted}) async {
    try {
      AgoraUser _temp =
          state.activeUsers.singleWhere((element) => element.uid == uid);
      Set<AgoraUser> _tempSet = state.activeUsers;
      _tempSet.remove(_temp);
      _tempSet.add(_temp.copyWith(muted: muted));
      state = state.copyWith(activeUsers: _tempSet);
    } catch (e) {
      return;
    }
  }

  Future<void> toggleUserVideo(
      {required int index, required bool enable}) async {
    if (enable) {
      state.channel!.sendMessage(AgoraRtmMessage.fromText(
          "disable ${state.activeUsers.elementAt(index).uid}"));
    } else {
      state.channel!.sendMessage(AgoraRtmMessage.fromText(
          "enable ${state.activeUsers.elementAt(index).uid}"));
    }
  }

  Future<void> updateUserVideo(
      {required int uid, required bool videoDisabled}) async {
    try {
      AgoraUser _temp =
          state.activeUsers.singleWhere((element) => element.uid == uid);
      Set<AgoraUser> _tempSet = state.activeUsers;
      _tempSet.remove(_temp);
      _tempSet.add(_temp.copyWith(videoDisabled: videoDisabled));
      state = state.copyWith(activeUsers: _tempSet);
    } catch (e) {
      return;
    }
  }

  Future<void> addUserToLobby({required int uid}) async {
    var userAttributes = await state.client?.getUserAttributes(uid.toString());
    state = state.copyWith(lobbyUsers: {
      ...state.lobbyUsers,
      AgoraUser(
        uid: uid,
        muted: true,
        videoDisabled: true,
        name: userAttributes?['name'],
        backgroundColor: Color(int.parse(userAttributes?['color'])),
      )
    });
    state.channel!.sendMessage(AgoraRtmMessage.fromText(
        Message().sendActiveUsers(activeUsers: state.activeUsers)));
  }

  Future<void> promoteToActiveUser({required int uid}) async {
    Set<AgoraUser> _tempLobby = state.lobbyUsers;
    Color? tempColor;
    String? tempName;
    for (int i = 0; i < _tempLobby.length; i++) {
      if (_tempLobby.elementAt(i).uid == uid) {
        tempColor = _tempLobby.elementAt(i).backgroundColor;
        tempName = _tempLobby.elementAt(i).name;
        _tempLobby.remove(_tempLobby.elementAt(i));
      }
    }
    state = state.copyWith(activeUsers: {
      ...state.activeUsers,
      AgoraUser(
        uid: uid,
        backgroundColor: tempColor,
        name: tempName,
      )
    }, lobbyUsers: _tempLobby);
    state.channel!.sendMessage(AgoraRtmMessage.fromText("unmute $uid"));
    state.channel!.sendMessage(AgoraRtmMessage.fromText("enable $uid"));
    state.channel!.sendMessage(AgoraRtmMessage.fromText(
        Message().sendActiveUsers(activeUsers: state.activeUsers)));

    if (state.isLive) {
      updateStream();
    }
  }

  Future<void> demoteToLobbyUser({required int uid}) async {
    Set<AgoraUser> _temp = state.activeUsers;
    Color? tempColor;
    String? tempName;
    for (int i = 0; i < _temp.length; i++) {
      if (_temp.elementAt(i).uid == uid) {
        tempColor = _temp.elementAt(i).backgroundColor;
        tempName = _temp.elementAt(i).name;
        _temp.remove(_temp.elementAt(i));
      }
    }
    state = state.copyWith(activeUsers: _temp, lobbyUsers: {
      ...state.lobbyUsers,
      AgoraUser(
        uid: uid,
        videoDisabled: true,
        muted: true,
        backgroundColor: tempColor,
        name: tempName,
      )
    });
    state.channel!.sendMessage(AgoraRtmMessage.fromText("mute $uid"));
    state.channel!.sendMessage(AgoraRtmMessage.fromText("disable $uid"));
    state.channel!.sendMessage(AgoraRtmMessage.fromText(
        Message().sendActiveUsers(activeUsers: state.activeUsers)));

    if (state.isLive) {
      updateStream();
    }
  }

  Future<void> removeUser({required int uid}) async {
    Set<AgoraUser> _temp = state.activeUsers;
    Set<AgoraUser> _tempLobby = state.lobbyUsers;
    for (int i = 0; i < _temp.length; i++) {
      if (_temp.elementAt(i).uid == uid) {
        _temp.remove(_temp.elementAt(i));
      }
    }
    for (int i = 0; i < _tempLobby.length; i++) {
      if (_tempLobby.elementAt(i).uid == uid) {
        _tempLobby.remove(_tempLobby.elementAt(i));
      }
    }
    state = state.copyWith(activeUsers: _temp, lobbyUsers: _tempLobby);

    if (state.isLive) {
      updateStream();
    }
  }

  Future<void> startStream() async {
    List<TranscodingUser> transcodingUsers = [];
    if (state.activeUsers.isEmpty) {
    } else if (state.activeUsers.length == 1) {
      transcodingUsers.add(TranscodingUser(
          uid: state.activeUsers.elementAt(0).uid,
          x: 0,
          y: 0,
          width: 1920,
          height: 1080,
          zOrder: 1,
          alpha: 1));
    } else if (state.activeUsers.length == 2) {
      transcodingUsers.add(TranscodingUser(
          uid: state.activeUsers.elementAt(0).uid,
          x: 0,
          y: 0,
          width: 960,
          height: 1080));
      transcodingUsers.add(TranscodingUser(
          uid: state.activeUsers.elementAt(1).uid,
          x: 960,
          y: 0,
          width: 960,
          height: 1080));
    } else if (state.activeUsers.length == 3) {
      transcodingUsers.add(TranscodingUser(
          uid: state.activeUsers.elementAt(0).uid,
          x: 0,
          y: 0,
          width: 640,
          height: 1080));
      transcodingUsers.add(TranscodingUser(
          uid: state.activeUsers.elementAt(1).uid,
          x: 640,
          y: 0,
          width: 640,
          height: 1080));
      transcodingUsers.add(TranscodingUser(
          uid: state.activeUsers.elementAt(2).uid,
          x: 1280,
          y: 0,
          width: 640,
          height: 1080));
    } else if (state.activeUsers.length == 4) {
      transcodingUsers.add(TranscodingUser(
          uid: state.activeUsers.elementAt(0).uid,
          x: 0,
          y: 0,
          width: 960,
          height: 540));
      transcodingUsers.add(TranscodingUser(
          uid: state.activeUsers.elementAt(1).uid,
          x: 960,
          y: 0,
          width: 960,
          height: 540));
      transcodingUsers.add(TranscodingUser(
          uid: state.activeUsers.elementAt(2).uid,
          x: 0,
          y: 540,
          width: 960,
          height: 540));
      transcodingUsers.add(TranscodingUser(
          uid: state.activeUsers.elementAt(3).uid,
          x: 960,
          y: 540,
          width: 960,
          height: 540));
    } else if (state.activeUsers.length == 5) {
      transcodingUsers.add(TranscodingUser(
          uid: state.activeUsers.elementAt(0).uid,
          x: 0,
          y: 0,
          width: 640,
          height: 540));
      transcodingUsers.add(TranscodingUser(
          uid: state.activeUsers.elementAt(1).uid,
          x: 640,
          y: 0,
          width: 640,
          height: 540));
      transcodingUsers.add(TranscodingUser(
          uid: state.activeUsers.elementAt(2).uid,
          x: 1280,
          y: 0,
          width: 640,
          height: 540));
      transcodingUsers.add(TranscodingUser(
          uid: state.activeUsers.elementAt(3).uid,
          x: 0,
          y: 540,
          width: 960,
          height: 540));
      transcodingUsers.add(TranscodingUser(
          uid: state.activeUsers.elementAt(4).uid,
          x: 960,
          y: 540,
          width: 960,
          height: 540));
    } else if (state.activeUsers.length == 6) {
      transcodingUsers.add(TranscodingUser(
          uid: state.activeUsers.elementAt(0).uid,
          x: 0,
          y: 0,
          width: 640,
          height: 540));
      transcodingUsers.add(TranscodingUser(
          uid: state.activeUsers.elementAt(1).uid,
          x: 640,
          y: 0,
          width: 640,
          height: 540));
      transcodingUsers.add(TranscodingUser(
          uid: state.activeUsers.elementAt(2).uid,
          x: 1280,
          y: 0,
          width: 640,
          height: 540));
      transcodingUsers.add(TranscodingUser(
          uid: state.activeUsers.elementAt(3).uid,
          x: 0,
          y: 540,
          width: 640,
          height: 540));
      transcodingUsers.add(TranscodingUser(
          uid: state.activeUsers.elementAt(4).uid,
          x: 640,
          y: 540,
          width: 640,
          height: 540));
      transcodingUsers.add(TranscodingUser(
          uid: state.activeUsers.elementAt(5).uid,
          x: 1280,
          y: 540,
          width: 640,
          height: 540));
    } else if (state.activeUsers.length == 7) {
      transcodingUsers.add(TranscodingUser(
          uid: state.activeUsers.elementAt(0).uid,
          x: 0,
          y: 0,
          width: 480,
          height: 540));
      transcodingUsers.add(TranscodingUser(
          uid: state.activeUsers.elementAt(1).uid,
          x: 480,
          y: 0,
          width: 480,
          height: 540));
      transcodingUsers.add(TranscodingUser(
          uid: state.activeUsers.elementAt(2).uid,
          x: 960,
          y: 0,
          width: 480,
          height: 540));
      transcodingUsers.add(TranscodingUser(
          uid: state.activeUsers.elementAt(3).uid,
          x: 1440,
          y: 0,
          width: 480,
          height: 540));
      transcodingUsers.add(TranscodingUser(
          uid: state.activeUsers.elementAt(4).uid,
          x: 0,
          y: 540,
          width: 640,
          height: 540));
      transcodingUsers.add(TranscodingUser(
          uid: state.activeUsers.elementAt(5).uid,
          x: 640,
          y: 540,
          width: 640,
          height: 540));
      transcodingUsers.add(TranscodingUser(
          uid: state.activeUsers.elementAt(6).uid,
          x: 1280,
          y: 540,
          width: 640,
          height: 540));
    } else if (state.activeUsers.length == 8) {
      transcodingUsers.add(TranscodingUser(
          uid: state.activeUsers.elementAt(0).uid,
          x: 0,
          y: 0,
          width: 480,
          height: 540));
      transcodingUsers.add(TranscodingUser(
          uid: state.activeUsers.elementAt(1).uid,
          x: 480,
          y: 0,
          width: 480,
          height: 540));
      transcodingUsers.add(TranscodingUser(
          uid: state.activeUsers.elementAt(2).uid,
          x: 960,
          y: 0,
          width: 480,
          height: 540));
      transcodingUsers.add(TranscodingUser(
          uid: state.activeUsers.elementAt(3).uid,
          x: 1440,
          y: 0,
          width: 480,
          height: 540));
      transcodingUsers.add(TranscodingUser(
          uid: state.activeUsers.elementAt(4).uid,
          x: 0,
          y: 540,
          width: 480,
          height: 540));
      transcodingUsers.add(TranscodingUser(
          uid: state.activeUsers.elementAt(5).uid,
          x: 480,
          y: 540,
          width: 480,
          height: 540));
      transcodingUsers.add(TranscodingUser(
          uid: state.activeUsers.elementAt(6).uid,
          x: 960,
          y: 540,
          width: 480,
          height: 540));
      transcodingUsers.add(TranscodingUser(
          uid: state.activeUsers.elementAt(7).uid,
          x: 1440,
          y: 540,
          width: 480,
          height: 540));
    } else {
      throw ("too many members");
    }

    LiveTranscoding transcoding = LiveTranscoding(
      transcodingUsers: transcodingUsers,
      width: 1920,
      height: 1080,
    );
    state.engine!.updateRtmpTranscoding(transcoding);
    for (int i = 0; i < state.destinations.length; i++) {
      print("STREAMING TO: ${state.destinations[i].url}");
      state.engine!
          .startRtmpStreamWithoutTranscoding(state.destinations[i].url);
    }

    state = state.copyWith(isLive: true);
  }

  Future<void> updateStream() async {
    List<TranscodingUser> transcodingUsers = [];
    if (state.activeUsers.isEmpty) {
    } else if (state.activeUsers.length == 1) {
      transcodingUsers.add(TranscodingUser(
          uid: state.activeUsers.elementAt(0).uid,
          x: 0,
          y: 0,
          width: 1920,
          height: 1080,
          zOrder: 1,
          alpha: 1));
    } else if (state.activeUsers.length == 2) {
      transcodingUsers.add(TranscodingUser(
          uid: state.activeUsers.elementAt(0).uid,
          x: 0,
          y: 0,
          width: 960,
          height: 1080));
      transcodingUsers.add(TranscodingUser(
          uid: state.activeUsers.elementAt(1).uid,
          x: 960,
          y: 0,
          width: 960,
          height: 1080));
    } else if (state.activeUsers.length == 3) {
      transcodingUsers.add(TranscodingUser(
          uid: state.activeUsers.elementAt(0).uid,
          x: 0,
          y: 0,
          width: 640,
          height: 1080));
      transcodingUsers.add(TranscodingUser(
          uid: state.activeUsers.elementAt(1).uid,
          x: 640,
          y: 0,
          width: 640,
          height: 1080));
      transcodingUsers.add(TranscodingUser(
          uid: state.activeUsers.elementAt(2).uid,
          x: 1280,
          y: 0,
          width: 640,
          height: 1080));
    } else if (state.activeUsers.length == 4) {
      transcodingUsers.add(TranscodingUser(
          uid: state.activeUsers.elementAt(0).uid,
          x: 0,
          y: 0,
          width: 960,
          height: 540));
      transcodingUsers.add(TranscodingUser(
          uid: state.activeUsers.elementAt(1).uid,
          x: 960,
          y: 0,
          width: 960,
          height: 540));
      transcodingUsers.add(TranscodingUser(
          uid: state.activeUsers.elementAt(2).uid,
          x: 0,
          y: 540,
          width: 960,
          height: 540));
      transcodingUsers.add(TranscodingUser(
          uid: state.activeUsers.elementAt(3).uid,
          x: 960,
          y: 540,
          width: 960,
          height: 540));
    } else if (state.activeUsers.length == 5) {
      transcodingUsers.add(TranscodingUser(
          uid: state.activeUsers.elementAt(0).uid,
          x: 0,
          y: 0,
          width: 640,
          height: 540));
      transcodingUsers.add(TranscodingUser(
          uid: state.activeUsers.elementAt(1).uid,
          x: 640,
          y: 0,
          width: 640,
          height: 540));
      transcodingUsers.add(TranscodingUser(
          uid: state.activeUsers.elementAt(2).uid,
          x: 1280,
          y: 0,
          width: 640,
          height: 540));
      transcodingUsers.add(TranscodingUser(
          uid: state.activeUsers.elementAt(3).uid,
          x: 0,
          y: 540,
          width: 960,
          height: 540));
      transcodingUsers.add(TranscodingUser(
          uid: state.activeUsers.elementAt(4).uid,
          x: 960,
          y: 540,
          width: 960,
          height: 540));
    } else if (state.activeUsers.length == 6) {
      transcodingUsers.add(TranscodingUser(
          uid: state.activeUsers.elementAt(0).uid,
          x: 0,
          y: 0,
          width: 640,
          height: 540));
      transcodingUsers.add(TranscodingUser(
          uid: state.activeUsers.elementAt(1).uid,
          x: 640,
          y: 0,
          width: 640,
          height: 540));
      transcodingUsers.add(TranscodingUser(
          uid: state.activeUsers.elementAt(2).uid,
          x: 1280,
          y: 0,
          width: 640,
          height: 540));
      transcodingUsers.add(TranscodingUser(
          uid: state.activeUsers.elementAt(3).uid,
          x: 0,
          y: 540,
          width: 640,
          height: 540));
      transcodingUsers.add(TranscodingUser(
          uid: state.activeUsers.elementAt(4).uid,
          x: 640,
          y: 540,
          width: 640,
          height: 540));
      transcodingUsers.add(TranscodingUser(
          uid: state.activeUsers.elementAt(5).uid,
          x: 1280,
          y: 540,
          width: 640,
          height: 540));
    } else if (state.activeUsers.length == 7) {
      transcodingUsers.add(TranscodingUser(
          uid: state.activeUsers.elementAt(0).uid,
          x: 0,
          y: 0,
          width: 480,
          height: 540));
      transcodingUsers.add(TranscodingUser(
          uid: state.activeUsers.elementAt(1).uid,
          x: 480,
          y: 0,
          width: 480,
          height: 540));
      transcodingUsers.add(TranscodingUser(
          uid: state.activeUsers.elementAt(2).uid,
          x: 960,
          y: 0,
          width: 480,
          height: 540));
      transcodingUsers.add(TranscodingUser(
          uid: state.activeUsers.elementAt(3).uid,
          x: 1440,
          y: 0,
          width: 480,
          height: 540));
      transcodingUsers.add(TranscodingUser(
          uid: state.activeUsers.elementAt(4).uid,
          x: 0,
          y: 540,
          width: 640,
          height: 540));
      transcodingUsers.add(TranscodingUser(
          uid: state.activeUsers.elementAt(5).uid,
          x: 640,
          y: 540,
          width: 640,
          height: 540));
      transcodingUsers.add(TranscodingUser(
          uid: state.activeUsers.elementAt(6).uid,
          x: 1280,
          y: 540,
          width: 640,
          height: 540));
    } else if (state.activeUsers.length == 8) {
      transcodingUsers.add(TranscodingUser(
          uid: state.activeUsers.elementAt(0).uid,
          x: 0,
          y: 0,
          width: 480,
          height: 540));
      transcodingUsers.add(TranscodingUser(
          uid: state.activeUsers.elementAt(1).uid,
          x: 480,
          y: 0,
          width: 480,
          height: 540));
      transcodingUsers.add(TranscodingUser(
          uid: state.activeUsers.elementAt(2).uid,
          x: 960,
          y: 0,
          width: 480,
          height: 540));
      transcodingUsers.add(TranscodingUser(
          uid: state.activeUsers.elementAt(3).uid,
          x: 1440,
          y: 0,
          width: 480,
          height: 540));
      transcodingUsers.add(TranscodingUser(
          uid: state.activeUsers.elementAt(4).uid,
          x: 0,
          y: 540,
          width: 480,
          height: 540));
      transcodingUsers.add(TranscodingUser(
          uid: state.activeUsers.elementAt(5).uid,
          x: 480,
          y: 540,
          width: 480,
          height: 540));
      transcodingUsers.add(TranscodingUser(
          uid: state.activeUsers.elementAt(6).uid,
          x: 960,
          y: 540,
          width: 480,
          height: 540));
      transcodingUsers.add(TranscodingUser(
          uid: state.activeUsers.elementAt(7).uid,
          x: 1440,
          y: 540,
          width: 480,
          height: 540));
    } else {
      throw ("too many members");
    }

    LiveTranscoding transcoding = LiveTranscoding(
      transcodingUsers: transcodingUsers,
      width: 1920,
      height: 1080,
    );
    state.engine!.updateRtmpTranscoding(transcoding);
  }

  Future<void> endStream() async {
    for (int i = 0; i < state.destinations.length; i++) {
      state.engine!.stopRtmpStream(state.destinations[i].url);
    }
    state = state.copyWith(isLive: false);
  }

  Future<void> addPublishDestination(
      StreamPlatform platform, String url) async {
    if (state.isLive) {
      state.engine!.startRtmpStreamWithoutTranscoding(url);
    }
    state = state.copyWith(destinations: [
      ...state.destinations,
      StreamDestination(platform: platform, url: url)
    ]);
  }

  Future<void> removePublishDestination(String url) async {
    if (state.isLive) {
      state.engine!.stopRtmpStream(url);
    }
    List<StreamDestination> temp = state.destinations;
    for (int i = 0; i < temp.length; i++) {
      if (temp[i].url == url) {
        temp.removeAt(i);
        state = state.copyWith(destinations: temp);
        return;
      }
    }
  }
}

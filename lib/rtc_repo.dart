import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:agora_rtm/agora_rtm.dart';
import 'package:demoagora1/controllers/director_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

final rtcRepoProvider = Provider<RtcRepo>((ref) => RtcRepo(ref.read));

class RtcRepo {
  Reader read;
  RtcRepo(this.read);

  Future<AgoraRtmChannel?> joinCallAsDirector(RtcEngine engine,
      AgoraRtmClient client, String channelName, int uid) async {
    await [Permission.camera, Permission.microphone].request();
    engine.registerEventHandler(
      RtcEngineEventHandler(
          onError: (code, str) {
            print(code);
          },
          onJoinChannelSuccess: (channel, uid) {
            print("DIRECTOR $uid");
          },
          onLeaveChannel: (stats, j) {},
          onUserJoined: (channel, uid, elapsed) {
            print("USER JOINED " + uid.toString());
            read(directorController.notifier).addUserToLobby(uid: uid);
          },
          onUserInfoUpdated: (uid, UserInfo info) {},
          onUserOffline: (channel, uid, reason) {
            read(directorController.notifier).removeUser(uid: uid);
          },
          onRemoteAudioStateChanged: (channel, uid, state, reason, elapsed) {
            if ((state == RemoteAudioState.remoteAudioStateDecoding) &&
                (reason ==
                    RemoteAudioStateReason.remoteAudioReasonRemoteUnmuted)) {
              read(directorController.notifier)
                  .updateUserAudio(uid: uid, muted: false);
            } else if ((state == RemoteAudioState.remoteAudioStateStopped) &&
                (reason ==
                    RemoteAudioStateReason.remoteAudioReasonRemoteMuted)) {
              read(directorController.notifier)
                  .updateUserAudio(uid: uid, muted: true);
            }
          },
          onRemoteVideoStateChanged: (channel, uid, state, reason, elapsed) {
            if ((state == RemoteVideoState.remoteVideoStateDecoding) &&
                (reason ==
                    RemoteVideoStateReason
                        .remoteVideoStateReasonRemoteUnmuted)) {
              read(directorController.notifier)
                  .updateUserVideo(uid: uid, videoDisabled: false);
            } else if ((state == RemoteVideoState.remoteVideoStateStopped) &&
                (reason ==
                    RemoteVideoStateReason.remoteVideoStateReasonRemoteMuted)) {
              read(directorController.notifier)
                  .updateUserVideo(uid: uid, videoDisabled: true);
            }
          },
          // on
          // streamPublished: (url, error) {
          //   print("Stream published to $url");
          // },
          // streamUnpublished: (url) {
          //   print("Stream unpublished from $url");
          // },
          onRtmpStreamingStateChanged: (url, state, errorCode) {
            print("Stream State Changed for $url to state $state");
          }),
    );
    engine.setChannelProfile(ChannelProfileType.channelProfileLiveBroadcasting);
    engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    engine.enableVideo();

    client.onMessageReceived = (AgoraRtmMessage message, String peerId) {
      print("Private Message from " + peerId + ": " + (message.text));
    };
    client.onConnectionStateChanged = (int state, int reason) {
      print('Connection state changed: ' +
          state.toString() +
          ', reason: ' +
          reason.toString());
      if (state == 5) {
        client.logout();
        print('Logout.');
      }
    };

    //join channels
    client.login(null, uid.toString());
    AgoraRtmChannel? _channel = await client.createChannel(channelName);
    _channel?.join();
    engine.joinChannel(
      token:
          "007eJxTYCh5WHZAeUPd91M3Gt75CKhMff6tyCLPUJiLWfiV7S2VkEwFBjODlBRzo+RUAwtzUxODFKPERBPTpBTDNFNT8zTLRMukNNHvyQ2BjAziJXdYGBkgEMTnYkgsLinKVyhJLS5hYAAAEPshYA==",
      channelId: "astro test",
      uid: uid,
      options: ChannelMediaOptions(),
    );

    _channel?.onAttributesUpdated =
        (List<AgoraRtmChannelAttribute> attributes) {
      print(attributes);
    };
    _channel?.onMemberJoined = (AgoraRtmMember member) {
      print(
          "Member joined: " + member.userId + ', channel: ' + member.channelId);
    };
    _channel?.onMemberLeft = (AgoraRtmMember member) {
      print("Member left: " + member.userId + ', channel: ' + member.channelId);
    };
    _channel?.onMessageReceived =
        (AgoraRtmMessage message, AgoraRtmMember member) {
      print("Public Message from " + member.userId + ": " + (message.text));
      // List<String> parsedMessage = message.text!.split(" ");
      // switch (parsedMessage[0]) {
      //   case "updateUser":
      //     read(directorController.notifier).updateUsers(message: parsedMessage[1]);
      //     break;
      //   default:
      // }
    };
    return _channel;
  }
}

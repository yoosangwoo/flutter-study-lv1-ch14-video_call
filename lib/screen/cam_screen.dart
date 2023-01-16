import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_call/const/agora.dart';

class CamScreen extends StatefulWidget {
  const CamScreen({Key? key}) : super(key: key);

  @override
  State<CamScreen> createState() => _CamScreenState();
}

class _CamScreenState extends State<CamScreen> {
  RtcEngine? engine;

  // 내 ID
  // 아이디를 받으려면 채널에 접속해야만 받을수있는데 채널 접속 전에는 내 아이디를 모르기때문에 임의로 0
  int? uid = 0;

  // 상대 ID
  // 처음에 시작할때 알고있지 않아도되서 null 로 둔다
  int? otherUid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('LIVE'),
      ),
      body: FutureBuilder<bool>(
          future: init(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  snapshot.error.toString(),
                ),
              );
            }

            if (!snapshot.hasData) {
              return Center(
                child: CircularProgressIndicator(),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      renderMainView(),
                      Align(
                        alignment: Alignment.topLeft,
                        child: Container(
                          color: Colors.grey,
                          width: 120,
                          height: 160,
                          child: renderSubView(),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: ElevatedButton(
                    onPressed: () async {
                      if (engine != null) {
                        await engine!.leaveChannel();
                        engine = null;
                      }

                      Navigator.of(context).pop();
                    },
                    child: Text('채널 나가기'),
                  ),
                ),
              ],
            );
          }),
    );
  }

  renderMainView() {
    if (uid == null) {
      return Center(
        child: Text('채널에 참여해주세요.'),
      );
    } else {
      // 채널에 함여하고 있을때
      return AgoraVideoView(
        controller: VideoViewController(
          rtcEngine: engine!,
          canvas: VideoCanvas(
            uid: 0,
          ),
        ),
      );
    }
  }

  renderSubView() {
    if (otherUid == null) {
      return Center(
        child: Text('채널에 유저가 없습니다.'),
      );
    } else {
      return AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: engine!,
          canvas: VideoCanvas(uid: otherUid),
          connection: RtcConnection(channelId: CHANNEL_NAME),
        ),
      );
    }
  }

  Future<bool> init() async {
    final resp = await [Permission.camera, Permission.microphone].request();

    final cameraPermission = resp[Permission.camera];
    final microphonePermission = resp[Permission.microphone];

    if (cameraPermission != PermissionStatus.granted ||
        microphonePermission != PermissionStatus.granted) {
      throw '카메라 또는 마이크 권한이 없습니다.';
    }

    // 엔진이 null이면 아고라RTC엔진을 생성
    if (engine == null) {
      engine = createAgoraRtcEngine();

      // 엔진을 APP_ID 기반으로 초기화
      await engine!.initialize(
        RtcEngineContext(
          appId: APP_ID,
        ),
      );

      // 엔진으로 여러가지 이벤트를 받을수있다
      // 4가지의 적절한 상황에 내 아이디와 상대 아이디를 세팅할수있다
      engine!.registerEventHandler(
        RtcEngineEventHandler(
          //내가 채널에 입장했을때
          // connection -> 연결정보
          // elapsed -> 연결된 시간 (연결된지 얼마나 됐는지)
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            print('채널에 입장했습니다. uid: ${connection.localUid}');
            setState(() {
              uid = connection.localUid;
            });
          },
          // 내가 채널에서 나갔을때
          onLeaveChannel: (RtcConnection connection, RtcStats stats) {
            print('채널 퇴장');
            setState(() {
              uid = null;
            });
          },
          // 상대방 유저가 들어왔을때
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            print('상대가 채널에 입장했습니다. otherUid: ${remoteUid}');
            setState(() {
              otherUid = remoteUid;
            });
          },
          // 상대방이 채널에서 나갔을때
          onUserOffline: (RtcConnection connection, int remoteUid,
              UserOfflineReasonType reason) {
            print('상대가 채널에서 나갔습니다. otherUid: ${remoteUid}');
            setState(() {
              otherUid = null;
            });
          },
        ),
      );
      //이제는 엔진을 시작하면 된다

      //순서대로 실행
      // 비디오 활성
      await engine!.enableVideo();
      // 카메라로 찍고 있는 모습을 핸드폰으로 송출
      await engine!.startPreview();
      // 여러가지 옵션들이 있음(아무것도 안적어도 기본값으로 세팅됨)
      ChannelMediaOptions options = ChannelMediaOptions();
      // 어떤 채널에 들어가서 화상채팅을 할지 정한다
      await engine!.joinChannel(
        token: TEMP_TOKEN,
        channelId: CHANNEL_NAME,
        uid: 0,
        options: options,
      );
    }

    return true;
  }
}

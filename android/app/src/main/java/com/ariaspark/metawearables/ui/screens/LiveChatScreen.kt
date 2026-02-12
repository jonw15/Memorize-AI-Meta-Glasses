package com.ariaspark.metawearables.ui.screens

import android.annotation.SuppressLint
import android.graphics.Bitmap
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.util.Base64
import android.view.ViewGroup
import android.webkit.PermissionRequest
import android.webkit.WebChromeClient
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.compose.animation.AnimatedContent
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import com.ariaspark.metawearables.R
import com.ariaspark.metawearables.ui.theme.*
import com.ariaspark.metawearables.viewmodels.WearablesViewModel
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import java.io.ByteArrayOutputStream

private enum class ChatMode {
    Menu, NewRoom, JoinRoom, InCall
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LiveChatScreen(
    wearablesViewModel: WearablesViewModel,
    onBackClick: () -> Unit
) {
    var mode by remember { mutableStateOf(ChatMode.Menu) }
    var roomCode by remember { mutableStateOf("") }
    var joinCode by remember { mutableStateOf("") }

    val activeRoomCode = if (roomCode.isNotEmpty()) roomCode else joinCode

    when (mode) {
        ChatMode.InCall -> {
            InCallView(
                roomCode = activeRoomCode,
                wearablesViewModel = wearablesViewModel,
                onHangup = onBackClick
            )
        }
        else -> {
            Scaffold(
                topBar = {
                    TopAppBar(
                        title = {
                            Text(
                                text = stringResource(R.string.feature_livechat_title),
                                fontWeight = FontWeight.SemiBold
                            )
                        },
                        navigationIcon = {
                            IconButton(onClick = {
                                if (mode == ChatMode.Menu) {
                                    onBackClick()
                                } else {
                                    mode = ChatMode.Menu
                                }
                            }) {
                                Icon(
                                    imageVector = if (mode == ChatMode.Menu) Icons.Default.Close
                                    else Icons.AutoMirrored.Filled.ArrowBack,
                                    contentDescription = stringResource(R.string.back)
                                )
                            }
                        }
                    )
                }
            ) { padding ->
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(padding)
                        .background(
                            Brush.linearGradient(
                                colors = listOf(
                                    LiveChatColor.copy(alpha = 0.1f),
                                    Secondary.copy(alpha = 0.1f)
                                )
                            )
                        )
                ) {
                    AnimatedContent(
                        targetState = mode,
                        label = "chat_mode"
                    ) { currentMode ->
                        when (currentMode) {
                            ChatMode.Menu -> MenuView(
                                onNewRoom = {
                                    roomCode = String.format("%04d", (0..9999).random())
                                    joinCode = ""
                                    mode = ChatMode.NewRoom
                                },
                                onJoinRoom = {
                                    joinCode = ""
                                    roomCode = ""
                                    mode = ChatMode.JoinRoom
                                }
                            )
                            ChatMode.NewRoom -> NewRoomView(
                                roomCode = roomCode,
                                onStart = { mode = ChatMode.InCall }
                            )
                            ChatMode.JoinRoom -> JoinRoomView(
                                joinCode = joinCode,
                                onJoinCodeChange = { joinCode = it },
                                onStart = {
                                    if (joinCode.isNotEmpty()) {
                                        mode = ChatMode.InCall
                                    }
                                }
                            )
                            else -> {}
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Menu View

@Composable
private fun MenuView(
    onNewRoom: () -> Unit,
    onJoinRoom: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = AppSpacing.large),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Spacer(modifier = Modifier.weight(1f))

        Box(
            modifier = Modifier
                .size(80.dp)
                .clip(CircleShape)
                .background(LiveChatColor.copy(alpha = 0.15f)),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = Icons.Default.VideoChat,
                contentDescription = null,
                tint = LiveChatColor,
                modifier = Modifier.size(40.dp)
            )
        }

        Spacer(modifier = Modifier.height(AppSpacing.medium))

        Text(
            text = stringResource(R.string.feature_livechat_title),
            fontSize = 28.sp,
            fontWeight = FontWeight.Bold,
            color = TextPrimaryLight
        )

        Spacer(modifier = Modifier.weight(1f))

        // New Room button
        Button(
            onClick = onNewRoom,
            modifier = Modifier
                .fillMaxWidth()
                .height(64.dp),
            shape = RoundedCornerShape(AppRadius.large),
            colors = ButtonDefaults.buttonColors(containerColor = Color.Transparent),
            contentPadding = PaddingValues()
        ) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(
                        Brush.horizontalGradient(
                            colors = listOf(LiveChatColor, LiveChatColor.copy(alpha = 0.8f))
                        )
                    ),
                contentAlignment = Alignment.Center
            ) {
                Row(
                    horizontalArrangement = Arrangement.Center,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        imageVector = Icons.Default.AddCircle,
                        contentDescription = null,
                        tint = Color.White,
                        modifier = Modifier.size(24.dp)
                    )
                    Spacer(modifier = Modifier.width(AppSpacing.small))
                    Text(
                        text = stringResource(R.string.livechat_new),
                        fontSize = 18.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = Color.White
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(AppSpacing.medium))

        // Join Room button
        OutlinedButton(
            onClick = onJoinRoom,
            modifier = Modifier
                .fillMaxWidth()
                .height(64.dp),
            shape = RoundedCornerShape(AppRadius.large),
            border = ButtonDefaults.outlinedButtonBorder(enabled = true),
            colors = ButtonDefaults.outlinedButtonColors(
                containerColor = LiveChatColor.copy(alpha = 0.12f),
                contentColor = LiveChatColor
            )
        ) {
            Icon(
                imageVector = Icons.Default.Group,
                contentDescription = null,
                modifier = Modifier.size(24.dp)
            )
            Spacer(modifier = Modifier.width(AppSpacing.small))
            Text(
                text = stringResource(R.string.livechat_join),
                fontSize = 18.sp,
                fontWeight = FontWeight.SemiBold
            )
        }

        Spacer(modifier = Modifier.weight(1f))
    }
}

// MARK: - New Room View

@Composable
private fun NewRoomView(
    roomCode: String,
    onStart: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = AppSpacing.large),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Spacer(modifier = Modifier.weight(1f))

        Text(
            text = stringResource(R.string.livechat_room_code),
            fontSize = 14.sp,
            color = TextSecondaryLight
        )

        Spacer(modifier = Modifier.height(AppSpacing.small))

        Text(
            text = roomCode,
            fontSize = 48.sp,
            fontWeight = FontWeight.Bold,
            fontFamily = FontFamily.Monospace,
            color = LiveChatColor,
            letterSpacing = 8.sp
        )

        Spacer(modifier = Modifier.height(AppSpacing.large))

        // QR Code
        val qrBitmap = remember(roomCode) {
            generateQRCode("https://app.ariaspark.com/webrtc/?a=$roomCode&autostart=true")
        }
        if (qrBitmap != null) {
            Box(
                modifier = Modifier
                    .size(200.dp)
                    .clip(RoundedCornerShape(AppRadius.medium))
                    .background(Color.White)
                    .padding(8.dp)
            ) {
                androidx.compose.foundation.Image(
                    bitmap = qrBitmap.asImageBitmap(),
                    contentDescription = "QR Code",
                    modifier = Modifier.fillMaxSize()
                )
            }
        }

        Spacer(modifier = Modifier.height(AppSpacing.medium))

        Text(
            text = stringResource(R.string.livechat_share_code),
            fontSize = 13.sp,
            color = TextSecondaryLight
        )

        Spacer(modifier = Modifier.weight(1f))

        Button(
            onClick = onStart,
            modifier = Modifier
                .fillMaxWidth()
                .height(56.dp),
            shape = RoundedCornerShape(AppRadius.large),
            colors = ButtonDefaults.buttonColors(containerColor = Color.Transparent),
            contentPadding = PaddingValues()
        ) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(
                        Brush.horizontalGradient(
                            colors = listOf(LiveChatColor, LiveChatColor.copy(alpha = 0.8f))
                        )
                    ),
                contentAlignment = Alignment.Center
            ) {
                Row(
                    horizontalArrangement = Arrangement.Center,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        imageVector = Icons.Default.Videocam,
                        contentDescription = null,
                        tint = Color.White,
                        modifier = Modifier.size(20.dp)
                    )
                    Spacer(modifier = Modifier.width(AppSpacing.small))
                    Text(
                        text = stringResource(R.string.livechat_start),
                        fontSize = 18.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = Color.White
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(AppSpacing.extraLarge))
    }
}

// MARK: - Join Room View

@Composable
private fun JoinRoomView(
    joinCode: String,
    onJoinCodeChange: (String) -> Unit,
    onStart: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = AppSpacing.large),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Spacer(modifier = Modifier.weight(1f))

        Box(
            modifier = Modifier
                .size(80.dp)
                .clip(CircleShape)
                .background(LiveChatColor.copy(alpha = 0.15f)),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = Icons.Default.Group,
                contentDescription = null,
                tint = LiveChatColor,
                modifier = Modifier.size(40.dp)
            )
        }

        Spacer(modifier = Modifier.height(AppSpacing.medium))

        Text(
            text = stringResource(R.string.livechat_join),
            fontSize = 28.sp,
            fontWeight = FontWeight.Bold,
            color = TextPrimaryLight
        )

        Spacer(modifier = Modifier.height(AppSpacing.large))

        OutlinedTextField(
            value = joinCode,
            onValueChange = { if (it.length <= 4) onJoinCodeChange(it.filter { c -> c.isDigit() }) },
            modifier = Modifier.fillMaxWidth(),
            textStyle = androidx.compose.ui.text.TextStyle(
                fontSize = 32.sp,
                fontWeight = FontWeight.Bold,
                fontFamily = FontFamily.Monospace,
                textAlign = TextAlign.Center
            ),
            placeholder = {
                Text(
                    text = stringResource(R.string.livechat_enter_code),
                    modifier = Modifier.fillMaxWidth(),
                    textAlign = TextAlign.Center,
                    fontSize = 18.sp,
                    color = TextSecondaryLight
                )
            },
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
            singleLine = true,
            shape = RoundedCornerShape(AppRadius.medium),
            colors = OutlinedTextFieldDefaults.colors(
                focusedBorderColor = LiveChatColor,
                cursorColor = LiveChatColor
            )
        )

        Spacer(modifier = Modifier.weight(1f))

        val enabled = joinCode.isNotEmpty()
        Button(
            onClick = onStart,
            enabled = enabled,
            modifier = Modifier
                .fillMaxWidth()
                .height(56.dp),
            shape = RoundedCornerShape(AppRadius.large),
            colors = ButtonDefaults.buttonColors(containerColor = Color.Transparent),
            contentPadding = PaddingValues()
        ) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(
                        Brush.horizontalGradient(
                            colors = if (enabled)
                                listOf(LiveChatColor, LiveChatColor.copy(alpha = 0.8f))
                            else
                                listOf(Color.Gray, Color.Gray.copy(alpha = 0.8f))
                        )
                    ),
                contentAlignment = Alignment.Center
            ) {
                Row(
                    horizontalArrangement = Arrangement.Center,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        imageVector = Icons.Default.Phone,
                        contentDescription = null,
                        tint = Color.White,
                        modifier = Modifier.size(20.dp)
                    )
                    Spacer(modifier = Modifier.width(AppSpacing.small))
                    Text(
                        text = stringResource(R.string.livechat_start),
                        fontSize = 18.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = Color.White
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(AppSpacing.extraLarge))
    }
}

// MARK: - In Call View

@SuppressLint("SetJavaScriptEnabled")
@Composable
private fun InCallView(
    roomCode: String,
    wearablesViewModel: WearablesViewModel,
    onHangup: () -> Unit
) {
    val context = LocalContext.current
    var isAudioMuted by remember { mutableStateOf(false) }
    var isVideoPaused by remember { mutableStateOf(false) }
    var webView by remember { mutableStateOf<WebView?>(null) }
    val currentFrame by wearablesViewModel.currentFrame.collectAsState()

    // Start streaming when entering call
    LaunchedEffect(Unit) {
        wearablesViewModel.startStream()
    }

    // Route audio through Bluetooth (glasses)
    LaunchedEffect(Unit) {
        val audioManager = context.getSystemService(android.content.Context.AUDIO_SERVICE) as AudioManager
        audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
        selectBluetoothDevice(audioManager)
        // Re-apply after WebView may override
        delay(2000)
        selectBluetoothDevice(audioManager)
    }

    // Send glasses frames to WebView at ~10fps
    LaunchedEffect(webView) {
        val wv = webView ?: return@LaunchedEffect
        while (isActive) {
            delay(100)
            val frame = currentFrame ?: continue
            val base64 = bitmapToBase64(frame)
            if (base64.isNotEmpty()) {
                wv.post {
                    wv.evaluateJavascript("window.__updateGlassesFrame('$base64');", null)
                }
            }
        }
    }

    // Cleanup on dispose
    DisposableEffect(Unit) {
        onDispose {
            val audioManager = context.getSystemService(android.content.Context.AUDIO_SERVICE) as AudioManager
            audioManager.mode = AudioManager.MODE_NORMAL
            wearablesViewModel.stopStream()
            webView?.destroy()
        }
    }

    Box(modifier = Modifier.fillMaxSize()) {
        // WebView
        AndroidView(
            factory = { ctx ->
                WebView(ctx).apply {
                    layoutParams = ViewGroup.LayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT,
                        ViewGroup.LayoutParams.MATCH_PARENT
                    )
                    settings.javaScriptEnabled = true
                    settings.mediaPlaybackRequiresUserGesture = false
                    settings.domStorageEnabled = true
                    settings.allowFileAccess = true

                    webChromeClient = object : WebChromeClient() {
                        override fun onPermissionRequest(request: PermissionRequest) {
                            request.grant(request.resources)
                        }
                    }

                    webViewClient = object : WebViewClient() {
                        override fun onPageStarted(view: WebView?, url: String?, favicon: Bitmap?) {
                            super.onPageStarted(view, url, favicon)
                            view?.evaluateJavascript(getUserMediaOverrideJS, null)
                        }

                        override fun shouldOverrideUrlLoading(
                            view: WebView?,
                            request: WebResourceRequest?
                        ): Boolean = false
                    }

                    val url = "https://app.ariaspark.com/webrtc/?a=$roomCode&autostart=true"
                    loadUrl(url)
                    webView = this
                }
            },
            modifier = Modifier.fillMaxSize()
        )

        // Top-left close button
        IconButton(
            onClick = onHangup,
            modifier = Modifier
                .statusBarsPadding()
                .padding(start = AppSpacing.medium, top = AppSpacing.small)
                .align(Alignment.TopStart)
        ) {
            Icon(
                imageVector = Icons.Default.Close,
                contentDescription = stringResource(R.string.close),
                tint = Color.White,
                modifier = Modifier.size(32.dp)
            )
        }

        // Bottom call controls
        Row(
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(bottom = 48.dp),
            horizontalArrangement = Arrangement.spacedBy(32.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Mute / Unmute Audio
            IconButton(
                onClick = {
                    webView?.evaluateJavascript("window.__toggleAudio();", null)
                    isAudioMuted = !isAudioMuted
                },
                modifier = Modifier
                    .size(56.dp)
                    .clip(CircleShape)
                    .background(
                        if (isAudioMuted) Color.Red.copy(alpha = 0.8f)
                        else Color.White.copy(alpha = 0.25f)
                    )
            ) {
                Icon(
                    imageVector = if (isAudioMuted) Icons.Default.MicOff else Icons.Default.Mic,
                    contentDescription = if (isAudioMuted)
                        stringResource(R.string.livechat_unmute)
                    else stringResource(R.string.livechat_mute),
                    tint = Color.White,
                    modifier = Modifier.size(22.dp)
                )
            }

            // Hangup
            IconButton(
                onClick = onHangup,
                modifier = Modifier
                    .size(64.dp)
                    .clip(CircleShape)
                    .background(Color.Red)
            ) {
                Icon(
                    imageVector = Icons.Default.CallEnd,
                    contentDescription = stringResource(R.string.livechat_hangup),
                    tint = Color.White,
                    modifier = Modifier.size(24.dp)
                )
            }

            // Pause / Resume Video
            IconButton(
                onClick = {
                    webView?.evaluateJavascript("window.__toggleVideo();", null)
                    isVideoPaused = !isVideoPaused
                },
                modifier = Modifier
                    .size(56.dp)
                    .clip(CircleShape)
                    .background(
                        if (isVideoPaused) Color.Red.copy(alpha = 0.8f)
                        else Color.White.copy(alpha = 0.25f)
                    )
            ) {
                Icon(
                    imageVector = if (isVideoPaused) Icons.Default.VideocamOff else Icons.Default.Videocam,
                    contentDescription = if (isVideoPaused)
                        stringResource(R.string.livechat_video_on)
                    else stringResource(R.string.livechat_video_off),
                    tint = Color.White,
                    modifier = Modifier.size(22.dp)
                )
            }
        }
    }
}

// MARK: - JavaScript Override

private val getUserMediaOverrideJS = """
(function() {
    var _style = document.createElement('style');
    _style.textContent = '.header { display: none !important; }' +
        '.callapp_local_video { position: fixed !important; top: 50px !important; right: 12px !important;' +
        ' width: 120px !important; height: 90px !important; border-radius: 10px !important;' +
        ' overflow: hidden !important; z-index: 9999 !important; border: 2px solid rgba(255,255,255,0.5) !important; }' +
        '.callapp_local_video video, .callapp_local_video canvas' +
        ' { width: 100% !important; height: 100% !important; object-fit: cover !important; }';
    document.documentElement.appendChild(_style);

    var _canvas = document.createElement('canvas');
    _canvas.width = 640;
    _canvas.height = 480;
    var _ctx = _canvas.getContext('2d');
    _ctx.fillStyle = '#000';
    _ctx.fillRect(0, 0, 640, 480);
    var _stream = _canvas.captureStream(30);

    var _localStreamId = null;
    var _gainNode = null;
    var _videoPaused = false;

    var _origGUM = navigator.mediaDevices.getUserMedia.bind(navigator.mediaDevices);

    navigator.mediaDevices.getUserMedia = function(constraints) {
        var needsVideo = constraints && constraints.video;
        var needsAudio = constraints && constraints.audio;

        if (needsVideo && needsAudio) {
            return _origGUM({ audio: constraints.audio }).then(function(audioStream) {
                var ac = new (window.AudioContext || window.webkitAudioContext)();
                _gainNode = ac.createGain();
                var src = ac.createMediaStreamSource(audioStream);
                var dest = ac.createMediaStreamDestination();
                src.connect(_gainNode);
                _gainNode.connect(dest);

                var combined = new MediaStream();
                _stream.getVideoTracks().forEach(function(t) { combined.addTrack(t); });
                dest.stream.getAudioTracks().forEach(function(t) { combined.addTrack(t); });
                _localStreamId = combined.id;
                return combined;
            });
        } else if (needsVideo) {
            var vs = new MediaStream(_stream.getVideoTracks());
            _localStreamId = vs.id;
            return Promise.resolve(vs);
        } else {
            return _origGUM(constraints);
        }
    };

    var _srcObjDesc = Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype, 'srcObject');
    if (_srcObjDesc && _srcObjDesc.set) {
        var _origSet = _srcObjDesc.set;
        Object.defineProperty(HTMLMediaElement.prototype, 'srcObject', {
            set: function(stream) {
                _origSet.call(this, stream);
                if (stream && _localStreamId && stream.id === _localStreamId) {
                    this.muted = true;
                    this.volume = 0;
                }
            },
            get: _srcObjDesc.get,
            configurable: true
        });
    }

    window.__toggleAudio = function() {
        if (_gainNode) {
            _gainNode.gain.value = _gainNode.gain.value > 0 ? 0 : 1;
        }
    };

    window.__toggleVideo = function() {
        _videoPaused = !_videoPaused;
        if (_videoPaused) {
            _ctx.fillStyle = '#000';
            _ctx.fillRect(0, 0, _canvas.width, _canvas.height);
        }
    };

    window.__updateGlassesFrame = function(b64) {
        if (_videoPaused) return;
        var img = new Image();
        img.onload = function() {
            if (_canvas.width !== img.width || _canvas.height !== img.height) {
                _canvas.width = img.width;
                _canvas.height = img.height;
            }
            _ctx.drawImage(img, 0, 0);
        };
        img.src = 'data:image/jpeg;base64,' + b64;
    };
})();
""".trimIndent()

// MARK: - Bluetooth Audio Helper

private fun selectBluetoothDevice(audioManager: AudioManager) {
    val devices = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
    val bluetoothDevice = devices.firstOrNull {
        it.type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO ||
                it.type == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP ||
                it.type == AudioDeviceInfo.TYPE_BLE_HEADSET
    }
    if (bluetoothDevice != null) {
        audioManager.setCommunicationDevice(bluetoothDevice)
    }
}

// MARK: - Bitmap to Base64 Helper

private fun bitmapToBase64(bitmap: Bitmap): String {
    val stream = ByteArrayOutputStream()
    bitmap.compress(Bitmap.CompressFormat.JPEG, 50, stream)
    val bytes = stream.toByteArray()
    return Base64.encodeToString(bytes, Base64.NO_WRAP)
}

// MARK: - QR Code Generation

private fun generateQRCode(content: String): Bitmap? {
    return try {
        val writer = com.google.zxing.qrcode.QRCodeWriter()
        val bitMatrix = writer.encode(
            content,
            com.google.zxing.BarcodeFormat.QR_CODE,
            512,
            512
        )
        val width = bitMatrix.width
        val height = bitMatrix.height
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.RGB_565)
        for (x in 0 until width) {
            for (y in 0 until height) {
                bitmap.setPixel(
                    x, y,
                    if (bitMatrix.get(x, y)) android.graphics.Color.BLACK
                    else android.graphics.Color.WHITE
                )
            }
        }
        bitmap
    } catch (e: Exception) {
        null
    }
}

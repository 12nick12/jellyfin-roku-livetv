'******************************************************
' Creates the capabilities object that is reported to Emby servers
'******************************************************

Function getDirectPlayProfiles(surroundSound, surroundSoundDCA)

	profiles = []
	
	versionArr = getGlobalVar("rokuVersion")
	audioContainers = "mp3,wma"
	
	if CheckMinimumVersion(versionArr, [5, 3]) then
		audioContainers = audioContainers + ",flac"
	end if

	device = CreateObject("roDeviceInfo")
 	model = left(device.GetModel(),4)
 	
	' roku 4 supports apple lossless audio codec
	if model = "4400" then
		audioContainers = audioContainers + ",alac"
	end if
	  
	profiles.push({
		Type: "Audio"
		Container: audioContainers
	})
	
	mp4Audio = "aac,mp3"
	
	if surroundSound then
		mp4Audio = mp4Audio + ",ac3"
	end if
	
	mp4Video = "h264,mpeg4"
	
	' roku 4 has support for hevc and vp9
	if model = "4400" then
		mp4Video = mp4Video + ",hevc,vp9"
	end if
	  
	profiles.push({
		Type: "Video"
		Container: "mp4,mov,m4v"
		VideoCodec: "h264,mpeg4"
		AudioCodec: mp4Audio
	})
	
	mkvAudio = "aac,mp3"
	
	mkvVideo = "h264,mpeg4"
	' roku 4 has support for hevc and vp9
	if model = "4400" then
		mkvVideo = mkvVideo + ",hevc,vp9"
	end if
	  
	if CheckMinimumVersion(versionArr, [5, 1]) then
	
	if surroundSound then
            mkvAudio = mkvAudio + ",ac3"
        end if

        if surroundSoundDCA then
            mkvAudio = mkvAudio + ",dca"
        end if

	if CheckMinimumVersion(versionArr, [5, 3]) then
		mkvAudio = mkvAudio + ",flac"
	end if
	
        profiles.push({
			Type: "Video"
			Container: "mkv"
			VideoCodec: "h264,mpeg4"
			AudioCodec: mkvAudio
		})
		
	end if

	return profiles

End Function

Function getTranscodingProfiles(surroundSound)

	profiles = []
	
	profiles.push({
		Type: "Audio"
		Container: "mp3"
		AudioCodec: "mp3"
		Context: "Streaming"
		Protocol: "Http"
	})
	
	videoAudioCodec = "mp3,aac"
	
	if surroundSound then
		videoAudioCodec = videoAudioCodec + ",ac3"
	end if
	
	profiles.push({
		Type: "Video"
		Container: "ts"
		AudioCodec: videoAudioCodec
		VideoCodec: "h264"
		Context: "Streaming"
		Protocol: "Hls"
	})

	return profiles

End Function

Function getCodecProfiles()

	profiles = []

	maxRefFrames = firstOf(getGlobalVar("maxRefFrames"), 12)
	playsAnamorphic = firstOf(getGlobalVar("playsAnamorphic"), false)
 	device = CreateObject("roDeviceInfo")
	model = left(device.GetModel(),4)
	
	maxWidth = "1920"
	maxHeight = "1080"
	max4kWidth = "3840"
	max4kHeight = "2160"
	
	if getGlobalVar("displayType") <> "HDTV" then
		maxWidth = "1280"
		maxHeight = "720"
	end if

	h264Conditions = []
	h264Conditions.push({
		Condition: "LessThanEqual"
		Property: "RefFrames"
		Value: tostr(maxRefFrames)
		IsRequired: false
	})
	h264Conditions.push({
		Condition: "LessThanEqual"
		Property: "VideoBitDepth"
		Value: "8"
		IsRequired: false
	})
	h264Conditions.push({
		Condition: "LessThanEqual"
		Property: "Width"
		Value: maxWidth
		IsRequired: true
	})
	h264Conditions.push({
		Condition: "LessThanEqual"
		Property: "Height"
		Value: maxHeight
		IsRequired: true
	})
	h264Conditions.push({
		Condition: "LessThanEqual"
		Property: "VideoFramerate"
		Value: "30"
		IsRequired: false
	})
	h264Conditions.push({
		Condition: "EqualsAny"
		Property: "VideoProfile"
		Value: "high|main|baseline|constrained baseline"
		IsRequired: false
	})
	h264Conditions.push({
		Condition: "LessThanEqual"
		Property: "VideoLevel"
		Value: "50"
		IsRequired: false
	})
	if playsAnamorphic = false Then
	h264Conditions.push({
		Condition: "Equals"
		Property: "IsAnamorphic"
		Value: "false"
		IsRequired: false
	})
	end if
	
		' roku4 has ability to direct play h265/hevc
	if model = "4400" then

	hevcConditions = []
	hevcConditions.push({
		Condition: "LessThanEqual"
		Property: "Width"
		Value: max4kWidth
		IsRequired: true
	})
	hevcConditions.push({
		Condition: "LessThanEqual"
		Property: "Height"
		Value: max4kHeight
		IsRequired: true
	})
	hevcConditions.push({
		Condition: "LessThanEqual"
		Property: "VideoFramerate"
		Value: "60"
		IsRequired: false
	})
	
	profiles.push({
		Type: "Video"
		Codec: "hevc"
		Conditions: hevcConditions
	})

	' roku4 has ability to direct play vp9 too
	vp9Conditions = []
	vp9Conditions.push({
		Condition: "LessThanEqual"
		Property: "Width"
		Value: max4kWidth
		IsRequired: true
	})
	vp9Conditions.push({
		Condition: "LessThanEqual"
		Property: "Height"
		Value: max4kHeight
		IsRequired: true
	})
	vp9Conditions.push({
		Condition: "LessThanEqual"
		Property: "VideoFramerate"
		Value: "30"
		IsRequired: false
	})

	profiles.push({
		Type: "Video"
		Codec: "vp9"
		Conditions: vp9Conditions
	})
	end if ' roku 4
	
	profiles.push({
		Type: "Video"
		Codec: "h264"
		Conditions: h264Conditions
	})
	
	mpeg4Conditions = []
	mpeg4Conditions.push({
		Condition: "LessThanEqual"
		Property: "RefFrames"
		Value: tostr(maxRefFrames)
		IsRequired: false
	})
	mpeg4Conditions.push({
		Condition: "LessThanEqual"
		Property: "VideoBitDepth"
		Value: "8"
		IsRequired: false
	})
	mpeg4Conditions.push({
		Condition: "LessThanEqual"
		Property: "Width"
		Value: maxWidth
		IsRequired: true
	})
	mpeg4Conditions.push({
		Condition: "LessThanEqual"
		Property: "Height"
		Value: maxHeight
		IsRequired: true
	})
	mpeg4Conditions.push({
		Condition: "LessThanEqual"
		Property: "VideoFramerate"
		Value: "30"
		IsRequired: false
	})
	mpeg4Conditions.push({
		Condition: "NotEquals"
		Property: "CodecTag"
		Value: "DX50"
		IsRequired: false
	})
	mpeg4Conditions.push({
		Condition: "NotEquals"
		Property: "CodecTag"
		Value: "XVID"
		IsRequired: false
	})
	if playsAnamorphic = false Then
	mpeg4Conditions.push({
		Condition: "Equals"
		Property: "IsAnamorphic"
		Value: "false"
		IsRequired: false
	})
	end if
	
	profiles.push({
		Type: "Video"
		Codec: "mpeg4"
		Conditions: mpeg4Conditions
	})
		
	profiles.push({
		Type: "VideoAudio"
		Codec: "mp3"
		Conditions: [{
			Condition: "Equals"
			Property: "IsSecondaryAudio"
			Value: "false"
			IsRequired: false
		},
		{
			Condition: "LessThanEqual"
			Property: "AudioChannels"
			Value: "2"
			IsRequired: true
		}]
	})
	
	if model = "4400" then
		AACchannels = "6"
	else
		AACchannels = "2"
	end if
	
	profiles.push({
		Type: "VideoAudio"
		Codec: "aac"
		Conditions: [{
			Condition: "Equals"
			Property: "IsSecondaryAudio"
			Value: "false"
			IsRequired: false
		},
		{
			Condition: "LessThanEqual"
			Property: "AudioChannels"
			Value: AACchannels
			IsRequired: true
		}]
	})
		
	profiles.push({
		Type: "VideoAudio"
		Codec: "ac3"
		Conditions: [{
			Condition: "Equals"
			Property: "IsSecondaryAudio"
			Value: "false"
			IsRequired: false
		},
		{
			Condition: "LessThanEqual"
			Property: "AudioChannels"
			Value: "6"
			IsRequired: false
		}]
	})
	
	return profiles

End Function

Function getContainerProfiles()

	profiles = []

	videoContainerConditions = []
	
	versionArr = getGlobalVar("rokuVersion")
    major = versionArr[0]

    if major < 4 then
		' If everything else looks ok and there are no audio streams, that's
		' fine on Roku 2+.
		videoContainerConditions.push({
			Condition: "NotEquals"
			Property: "NumAudioStreams"
			Value: "0"
			IsRequired: false
		})
	end if
	
	' Multiple video streams aren't supported, regardless of type.
    videoContainerConditions.push({
		Condition: "Equals"
		Property: "NumVideoStreams"
		Value: "1"
		IsRequired: false
	})
		
	profiles.push({
		Type: "Video"
		Conditions: videoContainerConditions
	})
	
	return profiles

End Function

Function getSubtitleProfiles()

	profiles = []
	
	profiles.push({
		Format: "srt"
		Method: "External"
		
		' If Roku adds support for non-Latin characters, remove this
		Language: "und,afr,alb,baq,bre,cat,dan,eng,fao,glg,ger,ice,may,gle,ita,lat,ltz,nor,oci,por,roh,gla,spa,swa,swe,wln,est,fin,fre,dut,fra"
	})
	
	profiles.push({
		Format: "srt"
		Method: "Embed"
		
		' If Roku adds support for non-Latin characters, remove this
		Language: "und,afr,alb,baq,bre,cat,dan,eng,fao,glg,ger,ice,may,gle,ita,lat,ltz,nor,oci,por,roh,gla,spa,swa,swe,wln,est,fin,fre,dut,fra"
	})
			
	return profiles

End Function

Function getDeviceProfile() 

	maxVideoBitrate = firstOf(RegRead("prefVideoQuality"), "3200")
	maxVideoBitrate = maxVideoBitrate.ToInt() * 1000
	
	surroundSound = SupportsSurroundSound(false, false)

	audioOutput51 = getGlobalVar("audioOutput51")
    surroundSoundDCA = surroundSound AND audioOutput51 'AND (RegRead("fivepointoneDCA", "preferences", "1") = "1")
    surroundSound = surroundSound AND audioOutput51 'AND (RegRead("fivepointone", "preferences", "1") = "1")
  
	profile = {
		MaxStaticBitrate: "40000000"
		MaxStreamingBitrate: tostr(maxVideoBitrate)
		MusicStreamingTranscodingBitrate: "192000"
		
		DirectPlayProfiles: getDirectPlayProfiles(surroundSound, surroundSoundDCA)
		TranscodingProfiles: getTranscodingProfiles(surroundSound)
		CodecProfiles: getCodecProfiles()
		ContainerProfiles: getContainerProfiles()
		SubtitleProfiles: getSubtitleProfiles()
		Name: "Roku"
	}
	
	return profile
	
End Function

Function getCapabilities() 

	caps = {
		PlayableMediaTypes: ["Audio","Video","Photo"]
		SupportsMediaControl: true
		SupportedCommands: ["MoveUp","MoveDown","MoveLeft","MoveRight","Select","Back","GoHome","SendString","GoToSearch","GoToSettings","DisplayContent","SetAudioStreamIndex","SetSubtitleStreamIndex"]
		MessageCallbackUrl: ":8324/emby/message"
		DeviceProfile: getDeviceProfile()
		SupportedLiveMediaTypes: ["Video"]
		AppStoreUrl: "https://www.roku.com/channels#!details/44191/emby"
		IconUrl: "https://raw.githubusercontent.com/wiki/MediaBrowser/Emby.Roku/Images/icon.png"
	}
	
	return caps
	
End Function

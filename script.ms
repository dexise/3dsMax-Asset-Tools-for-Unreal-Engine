fn get_script_path = (
	return pathConfig.removePathLeaf (getSourceFileName()) as string
)


fn get_ini_path = (
	return get_script_path() + "\\user-settings.ini"
)


fn getSetting key = (
	return getINISetting (get_ini_path()) "Default" (key)
)


fn getPathAsset subdir = (
	if (subdir == "" or subdir == undefined) then (
		return getSetting "Path_Asset"
	)

	return ((getSetting "Path_Asset") + "\\" + subdir)
)


fn path_model_export = (
	return getPathAsset "Model"
)


fn path_animation_export = (
	return getPathAsset "Animation"
)


fn makeDirectories = (
	path_asset = getSetting "Path_Asset"
	makeDir (path_model_export()) all:true
	makeDir (path_animation_export()) all:true
)


fn detectMeshName = (
	return trimRight (getFilenameFile maxFileName) "1234567890_"
)


fn isGeometry obj = (
	return superClassOf obj == geometryClass and classOf obj != Biped_Object
)


fn strhas source needle = (
	result = (findString (source as string) (needle)) != undefined
	return result
)


fn strReplace source find replace = (
	return substituteString source find replace
)


fn setSetting key value = (
	setINISetting (get_ini_path()) "Default" (key) value

	if (key == "Path_Asset") then (
		makeDirectories()
	)
)


fn export_meshes = (
	setExporterDefaultParams()

	exportPath = getSetting "Path_Asset"

	toExport = for i in selection collect i

	for i in toExport do (
		if (not isGeometry(i)) then (
			continue
		)

		if (not strhas i.name "Mesh_") then (
			continue
		)

		select i
		lastPos = i.pos
		i.pos = [0, 0, 0]
		mesh_name = strReplace i.name "Mesh_" ""
		filename = path_model_export() + "\\" + panel_export.txt_meshes_prefix.text + mesh_name + ".fbx"
		exportFile (filename) #noPrompt selectedOnly:true using:FBXEXP
		i.pos = lastPos
	)
)


fn createSockets = (
	deleteAllSockets()
	toCreateSocket = for i in objects collect i

	undo on (
		for i in toCreateSocket do (
			if (strhas i.name "Mesh_") then (
				socket = Dummy()
				socket.name = "Socket_" + (strReplace i.name "Mesh_" "")
				socket.transform = i.transform
				socket.parent = i.parent
			)
		)
	)
)


fn deleteAllSockets = (
	toDelete = for i in objects collect i

	undo on (
		for i in toDelete do (
			if (strhas i.name "Socket_") then (
				delete i
			)
		)
	)
)



fn setExporterDefaultParams = (
	FBXExporterSetParam "Cameras" false
	FBXExporterSetParam "ASCII" false
	FBXExporterSetParam "Animation" false
	FBXExporterSetParam "SmoothingGroups" true
	FBXExporterSetParam "SmoothMeshExport" true
	FBXExporterSetParam "UseSceneName" true
	FBXExporterSetParam "UpAxis" "Z"
	FBXExporterSetParam "Skin" true
	FBXExporterSetParam "Shape" true
)


fn export_skeletal_mesh = (
	setExporterDefaultParams()

	removeAdditionalAssets = panel_export.chk_remove_additional_meshes.state == on
	if (removeAdditionalAssets) then (
		toExport = for i in objects collect i

		undo on (
			for i in toExport do (
				if (strhas i.name "Mesh_") then (
					delete i
				)
			)
		)
	)

	exportName = panel_export.txt_skeletal_mesh_name.text
	exportPath = getSetting "Path_Asset"

	filename = path_model_export() + "\\" + exportName + ".fbx"
	exportFile (filename) #noPrompt selectedOnly:false using:FBXEXP

	if (removeAdditionalAssets) then (
		max undo
	)
)


fn export_animations = (
	setExporterDefaultParams()
	FBXExporterSetParam "Animation" true
	FBXExporterSetParam "BakeAnimation" true
	FBXExporterSetParam "BakeFrameStart" animationRange.start
	FBXExporterSetParam "BakeFrameEnd" animationRange.end
	FBXExporterSetParam "BakeFrameStep" 1
	FBXExporterSetParam "BakeResampleAnimation" false

	FbxImporterSetParam "Animation" true
	FbxImporterSetParam "AxisConversion" false
	FbxImporterSetParam "FillTimeline" true
	FbxImporterSetParam "FilterKeyReducer" false
	FbxImporterSetParam "FilterKeySync" false
	FbxImporterSetParam "ImportBoneAsDummy" false
	FbxImporterSetParam "KeepFrameRate" false
	FbxImporterSetParam "Markers" false
	FbxImporterSetParam "Mode" #merge
	FbxImporterSetParam "PointCache" false
	FbxImporterSetParam "ScaleConversion" false
	FbxImporterSetParam "Shape" true
	FbxImporterSetParam "Skin" false
	FbxImporterSetParam "SmoothingGroups" false
	FbxImporterSetParam "TakeIndex" 1
	FbxImporterSetParam "UpAxis" "Z"

	animations = selectMultipleFiles "Test" "FBX Files (*.fbx)|*.fbx"

	holdMaxFile() 
	toDelete = for i in objects collect i

	with redraw off (
		for i in toDelete do (
			if (isGeometry(i)) then (
				delete i
			)
		)
		
		for anim in animations do (
			importfile (anim) #noPrompt using:FBXIMP
			
			extractMotion()

			filename = path_animation_export() + "\\" + (getFilenameFile anim) + ".fbx"
			exportFile (filename) #noPrompt selectedOnly:false using:FBXEXP
			deleteAllAnimation()
		)
	)

	fetchMaxFile quiet:true
)


fn deleteAllAnimation = (
	lastSelection = for i in selection collect i

	biped.clearAllAnimation $Bip.controller

	select objects
	maxOps.deleteSelectedAnimation()

	select lastSelection
)


fn getRenameMap = (
	arr = #()
	struct data(bip, ue4, mixamo)

	append arr (data "" 				"Bip" 						"Bip")
	append arr (data " Pelvis" 			"Pelvis" 					"Hips")	
	append arr (data " Footsteps" 		"Footsteps" 				"Footsteps")		
	append arr (data " L Thigh" 		"Thigh_L" 					"LeftUpLeg")	
	append arr (data " R Thigh" 		"Thigh_R" 					"RightUpLeg")	
	append arr (data " L Calf" 			"Calf_L" 					"LeftLeg")	
	append arr (data " R Calf" 			"Calf_R" 					"RightLeg")	
	append arr (data " L Calf Twist"	"Calf_Twist_01_L" 			"LeftLegTwist1")			
	append arr (data " R Calf Twist"	"Calf_Twist_01_R" 			"RightLegTwist1")			
	append arr (data " L Foot"			"Foot_L" 					"LeftFoot")	
	append arr (data " R Foot"			"Foot_R" 					"RightFoot")	
	append arr (data " L Toe0" 			"Ball_L" 					"LeftToeBase")	
	append arr (data " R Toe0" 			"Ball_R" 					"RightToeBase")	
	append arr (data " L Toe0Nub" 		"Toe0Nub_L" 				"LeftFootToeBase_End")		
	append arr (data " R Toe0Nub" 		"Toe0Nub_R" 				"RightFootToeBase_End")		
	append arr (data " Spine" 			"Spine_01" 					"Spine")		
	append arr (data " Spine1" 			"Spine_02" 					"Spine1")		
	append arr (data " Spine2" 			"Spine_03" 					"Spine2")		
	append arr (data " LThighTwist" 	"Thigh_Twist_01_L" 			"LeftUpLegTwist1")				
	append arr (data " RThighTwist" 	"Thigh_Twist_01_R" 			"RightUpLegTwist1")				
	append arr (data " L Clavicle" 		"Clavicle_L" 				"LeftShoulder")		
	append arr (data " R Clavicle" 		"Clavicle_R" 				"RightShoulder")		
	append arr (data " Neck" 			"Neck" 						"Neck")	
	append arr (data " Neck1" 			"Neck_01" 					"Neck1")	
	append arr (data " Head" 			"Head" 						"Head")	
	append arr (data " HeadNub" 		"HeadNub" 					"HeadTop_End")	
	append arr (data " L UpperArm" 		"UpperArm_L" 				"LeftArm")		
	append arr (data " R UpperArm" 		"UpperArm_R" 				"RightArm")		
	append arr (data " LUpArmTwist" 	"UpperArm_Twist_01_L" 		"LeftArmTwist1")				
	append arr (data " RUpArmTwist" 	"UpperArm_Twist_01_R" 		"RightArmTwist1")				
	append arr (data " L Forearm" 		"LowerArm_L" 				"LeftForeArm")		
	append arr (data " R Forearm" 		"LowerArm_R" 				"RightForeArm")		
	append arr (data " L Hand" 			"Hand_L" 					"LeftHand")	
	append arr (data " R Hand" 			"Hand_R" 					"RightHand")	
	append arr (data " L ForeTwist" 	"LowerArm_Twist_01_L" 		"LeftForeArmTwist1")				
	append arr (data " R ForeTwist" 	"LowerArm_Twist_01_R" 		"RightForeArmTwist1")				
	append arr (data " L Finger0" 		"Thumb_01_L" 				"LeftHandThumb1")		
	append arr (data " L Finger01" 		"Thumb_02_L" 				"LeftHandThumb2")		
	append arr (data " L Finger02" 		"Thumb_03_L" 				"LeftHandThumb3")		
	append arr (data " L Finger0Nub" 	"ThumbNub_L" 				"LeftHandThumb4")		
	append arr (data " R Finger0" 		"Thumb_01_R" 				"RightHandThumb1")		
	append arr (data " R Finger01" 		"Thumb_02_R" 				"RightHandThumb2")		
	append arr (data " R Finger02" 		"Thumb_03_R" 				"RightHandThumb3")		
	append arr (data " R Finger0Nub" 	"ThumbNub_R" 				"RightHandThumb4")		
	append arr (data " L Finger1" 		"Index_01_L" 				"LeftHandIndex1")		
	append arr (data " L Finger11" 		"Index_02_L" 				"LeftHandIndex2")		
	append arr (data " L Finger12" 		"Index_03_L" 				"LeftHandIndex3")		
	append arr (data " L Finger1Nub" 	"IndexNub_L" 				"LeftHandIndex4")		
	append arr (data " R Finger1"		"Index_01_R" 				"RightHandIndex1")		
	append arr (data " R Finger11" 		"Index_02_R" 				"RightHandIndex2")		
	append arr (data " R Finger12" 		"Index_03_R" 				"RightHandIndex3")		
	append arr (data " R Finger1Nub" 	"IndexNub_R" 				"RightHandIndex4")		
	append arr (data " L Finger2" 		"Middle_01_L" 				"LeftHandMiddle1")		
	append arr (data " L Finger21" 		"Middle_02_L" 				"LeftHandMiddle2")		
	append arr (data " L Finger22" 		"Middle_03_L" 				"LeftHandMiddle3")		
	append arr (data " L Finger2Nub" 	"MiddleNub_L" 				"LeftHandMiddle4")		
	append arr (data " R Finger2" 		"Middle_01_R" 				"RightHandMiddle1")		
	append arr (data " R Finger21" 		"Middle_02_R" 				"RightHandMiddle2")		
	append arr (data " R Finger22" 		"Middle_03_R" 				"RightHandMiddle3")		
	append arr (data " R Finger2Nub" 	"MiddleNub_R" 				"RightHandMiddle4")		
	append arr (data " L Finger3" 		"Ring_01_L" 				"LeftHandRing1")		
	append arr (data " L Finger31" 		"Ring_02_L" 				"LeftHandRing2")		
	append arr (data " L Finger32" 		"Ring_03_L" 				"LeftHandRing3")		
	append arr (data " L Finger3Nub" 	"RingNub_L" 				"LeftHandRing4")		
	append arr (data " R Finger3" 		"Ring_01_R" 				"RightHandRing1")		
	append arr (data " R Finger31" 		"Ring_02_R" 				"RightHandRing2")		
	append arr (data " R Finger32" 		"Ring_03_R" 				"RightHandRing3")		
	append arr (data " R Finger3Nub" 	"RingNub_R" 				"RightHandRing4")		
	append arr (data " L Finger4" 		"Pinky_01_L" 				"LeftHandPinky1")		
	append arr (data " L Finger41" 		"Pinky_02_L" 				"LeftHandPinky2")		
	append arr (data " L Finger42" 		"Pinky_03_L" 				"LeftHandPinky3")		
	append arr (data " L Finger4Nub" 	"PinkyNub_L" 				"LeftHandPinky4")		
	append arr (data " R Finger4" 		"Pinky_01_R" 				"RightHandPinky1")		
	append arr (data " R Finger41" 		"Pinky_02_R" 				"RightHandPinky2")		
	append arr (data " R Finger42" 		"Pinky_03_R" 				"RightHandPinky3")		
	append arr (data " R Finger4Nub" 	"PinkyNub_R" 				"RightHandPinky4")		

	return arr
)


fn renameBipedToUE4 = (
	arr = getRenameMap()
	for i in arr do (
		obj = execute("$'" + "Bip" + (i.bip) + "'")
		if (obj != undefined) then (
			obj.name = i.ue4
		)
	)
)


fn renameBiped2Mixamo = (
	arr = getRenameMap()
	for i in arr do (
		obj = execute("$'" + "Bip" + (i.bip) + "'")
		if (obj != undefined) then (
			obj.name = i.mixamo
		)
	)
)


fn renameUE4toBiped = (
	arr = getRenameMap()
	for i in arr do (
		obj = execute("$'" + (i.ue4) + "'")
		if (obj != undefined) then (
			obj.name = "Bip" + i.bip
		)
	)
)


fn renameUE4toMixamo = (
	arr = getRenameMap()
	for i in arr do (
		obj = execute("$'" + (i.ue4) + "'")
		if (obj != undefined) then (
			obj.name = i.mixamo
		)
	)
)


fn renameMixamo2Biped = (
	arr = getRenameMap()
	for i in arr do (
		obj = execute("$'" + (i.mixamo) + "'")
		if (obj != undefined) then (
			obj.name = "Bip" + i.bip
		)
	)
)


fn renameMixamo2UE4 = (
	arr = getRenameMap()
	for i in arr do (
		obj = execute("$'" + (i.mixamo) + "'")
		if (obj != undefined) then (
			obj.name = i.ue4
		)
	)
)


fn isNamedBiped = (
	return ($'Bip L Thigh' != undefined)
)


fn isNamedUe4 = (
	return ($'Thigh_L' != undefined)
)


fn isNamedMixamo = (
	return ($'LeftUpLeg' != undefined)
)


fn rename2mixamo = (
	if (isNamedBiped()) then (
		renameBiped2Mixamo()
		return 0
	)

	if (isNamedUe4()) then (
		renameUE4toMixamo()
		return 0
	)
)


fn rename2ue4 = (
	if isNamedBiped() then (
		renameBipedToUE4()
		return 0
	)

	if isNamedMixamo() then (
		renameMixamo2UE4()
		return 0
	)
)


fn rename2biped = (
	if isNamedMixamo() then (
		renameMixamo2Biped()
		return 0
	)

	if isNamedUe4() then (
		renameUE4toBiped()
		return 0
	)
)


fn showSelectionInformation = (
	if (selection.count > 0) then (
		if (selection.count == 1) then (
			class = (classOf $) as string
			superclass = (superClassOf $) as string

			if (classOf $ == Biped_Object) then (
				pos = in coordsys world biped.getTransform $ #pos
				rot = in coordsys world biped.getTransform $ #rotation 
			) else (
				pos = in coordsys world $.pos 
				rot = in coordsys world $.rotation
			)
			gw.hText [150,5,0] ($.name + " : " + class + ":" + superclass + " @ " + (pos as string) + " " + (rot as string)) color:white
		) else (
			gw.hText [150,5,0] ((selection.count as string) + " objects selected") color:white
		)
	)
)


fn showInfo = (
	gw.setTransform(Matrix3 1)

	if ($Bip != undefined) do (
		if ($Bip.controller.figureMode) then (
			gw.hText [10,5,0] "Figure Mode Is On" color:Yellow
		) else (
			gw.hText [10,5,0] "Figure Mode Is Off" color:green
		)
	)
	
	--showSelectionInformation()

	gw.enlargeUpdateRect #whole
	gw.updateScreen()
)


fn enable_info = (
	registerRedrawViewsCallback showInfo
	showInfo()
	forceCompleteRedraw()
)


fn disable_info = (
	unRegisterRedrawViewsCallback showInfo
	forceCompleteRedraw()
)


fn computeSkin isPrecise = (
	falloff = panel_model.skin_falloff.value
	if (isPrecise) then (
		skinOps.voxelWeighting $.modifiers[#Skin] 1 falloff -1 512 off on
	) else (
		skinOps.voxelWeighting $.modifiers[#Skin] 0 falloff -1 512 off on
	)

	$.modifiers[#Skin].clearZeroLimit = 0.02
	skinOps.RemoveZeroWeights $.modifiers[#Skin]
)


fn removeSkin obj = (
	removeModifier obj Skin
)


fn skinIt = (
	--deleteAllAnimation()
	sliderTime = 0f
	if (selection.count != 1) then (
		return 0
	)
	
	removeSkin $
	theSkin = Skin()
	max modify mode
	
	addModifier $ theSkin
	modPanel.setCurrentObject theSkin
	skinOps.buttonInclude theSkin
	for i in objects do (
		if (classOf i == Biped_Object) do (
			skinOps.addBone theSkin i 1
		)
	)
)


fn cleanModel = (
	toDelete = #()
	geos = #()

	for i in selection do (
		if (classOf i == Dummy) do (
			append toDelete i
		)

		if (superClassOf i == GeometryClass) do (
			append geos i
		)
	)

	for i in geos do (
		removeSkin i

		ConvertTo i Editable_Poly
		select i
		PolyToolsModeling.Quadrify false false
		allVerts = #{1..(polyop.getNumVerts i)}
		i.weldThreshold = 0.001
		polyOp.weldVertsByThreshold i allVerts
	)

	for i in toDelete do (
		if (i != undefined) do (
			delete i
		)
	)
)


fn setPose index = (
	bipObject = $Bip
	bip = bipObject.controller
	bip.figureMode = true
	collection = biped.getCopyCollection bip 1
	pose = getCopy collection #pose index
	biped.pasteBipPose bip pose true #pstdefault false false false false
	bip.figureMode = false
)


fn createBiped = (
	bipObject = biped.createNew 200.0 -90 [0, 0, 192]
	bipName = bipObject.name
	bip = bipObject.controller

	bip.figureMode = true
	currentDir = pathConfig.removePathLeaf (getSourceFileName()) as string
	biped.LoadFigFile bip (currentDir + "\\assets\\mixamo.fig")
	biped.deleteAllCopyCollections bip
	biped.loadCopyPasteFile bip (currentDir + "\\assets\\Standard Poses.cpy")
	bip.figureMode = false
	execute("select $" + bipName + "...*")

	for i in selection do (
		i.name = (strReplace i.name bipName "Bip")
	)
)


fn extractMotion = (
	with redraw off (
		tempLastFrame = sliderTime
		sliderTime = 0f
		restore_anim()
		sliderTime = 0f
		processMotionRoot()
		sliderTime = tempLastFrame
	)
)


fn processMotionRoot = (
	target = Dummy()
	target.name = "root"
	target = $root
	
	hcontroller = $Bip.transform.controller.horizontal.controller
	tcontroller = $Bip.transform.controller.turning.controller
	keys = hcontroller.keys
	with animate on (
		for i in 1 to keys.count do (
			frame = keys[i].time.frame
			key = biped.getKey hcontroller i
			rkey = biped.getKey tcontroller i

			if panel_animation.mr_xpos.state then (
				value = at time frame key.x
				at time frame target.pos.x=value
				at time frame key.x=0
			)

			if panel_animation.mr_ypos.state then (
				value = at time frame key.y
				at time frame target.pos.y=value
				at time frame key.y=0
			)

			if panel_animation.mr_zpos.state then (
				value = at time frame key.z
				at time frame target.pos.z=value
				at time frame key.z=0
			)

			/*
			if panel_animation.mr_zrot.state then (
				value = at time frame rkey.rotation
				euler = quatToEuler2 value
				print euler.z
				at time frame target.rotation.z=euler.z
				--at time frame rkey.rotation=eulerToQuat (eulerAngles euler.x euler.y 0)
			)
			*/
		)
	)

	$Bip.parent = $root
)


fn restore_anim = (
	if ($root == undefined) then (
		return 0
	)

	tempLastFrame = sliderTime
	sliderTime = 0f

	$Bip.parent = undefined

	target = $root
	hcontroller = $Bip.transform.controller.horizontal.controller
	tcontroller = $Bip.transform.controller.turning.controller
	keys = hcontroller.keys

	with animate on (
		for i in 1 to keys.count do (
			frame = keys[i].time.frame
			key = biped.getKey hcontroller i
			rkey = biped.getKey tcontroller i
			if panel_animation.mr_xpos.state then (
				at time frame key.x=target.pos.x
			)

			if panel_animation.mr_ypos.state then (
				at time frame key.y=target.pos.y
			)

			if panel_animation.mr_zpos.state then (
				at time frame key.z=target.pos.z
			)
			
			/*
			if panel_animation.mr_zrot.state then (
				q = eulerToQuat target.rotation
				at time frame rkey.rotation=q
			)
			*/
		)
	)

	delete $root
	sliderTime = tempLastFrame
)



fn getLeftBones = (
	return for i in objects where (
		classOf i == Biped_Object and (
			strhas (i.name as string) "Left" or
			strhas (i.name as string) " L " or
			strhas (i.name as string) "_L" or
			strhas (i.name as string) " LUp" or
			strhas (i.name as string) " LT"
		)
	) collect i
)


fn getRightBones = (
	return for i in objects where (
		classOf i == Biped_Object and (
			strhas (i.name as string) "Right" or
			strhas (i.name as string) " R " or
			strhas (i.name as string) "_R" or
			strhas (i.name as string) " RUp" or
			strhas (i.name as string) " RT"
		)
	) collect i
)


fn getMiddleBones = (
	return for i in objects where (
		classOf i == Biped_Object and ( not (
			strhas (i.name as string) "Left" or
			strhas (i.name as string) " L " or
			strhas (i.name as string) "_L" or
			strhas (i.name as string) " LUp" or
			strhas (i.name as string) " LT" or
			strhas (i.name as string) "Right" or
			strhas (i.name as string) " R " or
			strhas (i.name as string) "_R" or
			strhas (i.name as string) " RUp" or
			strhas (i.name as string) " RT"
		))
	) collect i
)


fn containsModifier obj modifier = (
	if (obj.modifiers != undefined) then (
		for index = obj.modifiers.count to 1 by -1 do (
			if ((classOf obj.modifiers[index]) == modifier) do (
				return true
			)
		)
	)

	return false
)


fn removeModifier obj modifier = (
	if (obj.modifiers != undefined) then (
		for index = obj.modifiers.count to 1 by -1 do (
			if ((classOf obj.modifiers[index]) == modifier) do (
				deleteModifier obj index
			)
		)
	)
)


fn selectMultipleFiles title filters = (
	theDialog = dotNetObject "System.Windows.Forms.OpenFileDialog"
	theDialog.title = title
	theDialog.Multiselect = true
	theDialog.Filter = filters
	theDialog.FilterIndex = 0
	result = theDialog.showDialog()
	if (result.Equals == result.Cancel) then (
		print "canceled"
		return #()
	)

	theFilenames = theDialog.fileNames
	return theFilenames
)


fn makeUi = (
	global ui
	if (ui != undefined) then (
		for i in ui.rollouts do (
			removeRollout i ui
		)
	)

	global panel_animation
	global panel_export
	global panel_hide_freeze
	global panel_about
	global panel_biped
	global panel_model
	
	--if ui != undefined then CloseRolloutFloater ui


	rollout panel_hide_freeze "Hide and Freeze" rolledup:true (
		group "All Geometries" (
			button geo_hide "Hide" width: 66 across:3
			button geo_freeze "Freeze" width: 66
			button geo_seethrough "XRay" width: 66
			button geo_unhide "Unhide" width: 66 across:3
			button geo_unfreeze "Unfreeze" width: 66
			button geo_unseethrough "Solid" width: 66
		)

		group "All Bones" (
			button bone_hide_left "Hide L" width: 50 across:4
			button bone_hide_center "Hide C " width: 50
			button bone_hide_right "Hide R" width: 50
			button bone_unhide "Unhide" width: 50
		)

		on geo_hide pressed do ( for i in objects where (classOf i == Editable_Poly or classOf i == PolyMeshObject) do hide i )
		on geo_unhide pressed do ( for i in objects where (classOf i == Editable_Poly or classOf i == PolyMeshObject) do unhide i )
		on geo_freeze pressed do ( for i in objects where (classOf i == Editable_Poly or classOf i == PolyMeshObject) do freeze i )
		on geo_unfreeze pressed do ( for i in objects where (classOf i == Editable_Poly or classOf i == PolyMeshObject) do unfreeze i )
		on geo_seethrough pressed do ( for i in objects where (classOf i == Editable_Poly or classOf i == PolyMeshObject) do i.xray = true )
		on geo_unseethrough pressed do ( for i in objects where (classOf i == Editable_Poly or classOf i == PolyMeshObject) do i.xray = false )
		on bone_unhide pressed do ( for i in objects where classOf i == Biped_Object do unhide i )
		on bone_hide_left pressed do ( for i in getLeftBones() do hide i )
		on bone_hide_center pressed do ( for i in getMiddleBones() do hide i )
		on bone_hide_right pressed do ( for i in getRightBones() do hide i )
	)
	
	
	rollout panel_biped "Biped and Pose" rolledup:true (
		button create_biped "Make Bip" width: 50 across:4 
		button b_pose "B Pose" width:50
		button a_pose "A Pose" width:50
		button t_pose "T Pose" width:50
		checkbutton figure_mode "Figure" width:200
		
		group "Copy Right To Left" (
			button copy_right_to_left "All" width:100 across:2
			button copy_selected_right_to_left "Selected" width:100
		)

		group "Change Naming to: " (
			button rename_to_ue4 "UE4" width:66 across:3
			button rename_to_biped "Biped" width:66
			button rename_to_mixamo "Mixamo" width:66
		)

		on create_biped pressed do (
			createBiped()
		)
		
		on rename_to_ue4 pressed do (
			rename2ue4()
		)

		on rename_to_mixamo pressed do (
			rename2mixamo()
		)

		on rename_to_biped pressed do (
			rename2biped()
		)

		on b_pose pressed do (
			setPose 2
		)
		
		on a_pose pressed do (
			setPose 1
		)

		on t_pose pressed do (
			setPose 3
		)
		
		on figure_mode changed state do (
			bip = $Bip.controller

			if state == on then (
				bip.figureMode = true
			) else (
  				bip.figureMode = false
			)
		)

		on copy_right_to_left pressed do (
			bip = $Bip.controller
			
			undo on (
				rightBones = getRightBones()
				select rightBones

				collection = biped.getCopyCollection bip 1
				posture = biped.copyBipPosture bip collection rightBones #snapNone
				biped.pasteBipPosture bip posture true #pstdefault false false false false
			)
		)
		
		on copy_selected_right_to_left pressed do (
			bip = $Bip.controller
			
			undo on (
				rightBones = for i in selection collect i

				collection = biped.getCopyCollection bip 1
				posture = biped.copyBipPosture bip collection rightBones #snapNone
				biped.pasteBipPosture bip posture true #pstdefault false false false false
			)
		)
	)


	rollout panel_model "Model and Skin" rolledup:true (
		button clean_model "Clean Model" width: 200
		checkbutton draw_position_plane "Position Plane" orient:#vertical width: 200 align:#left
		button skin_it "(Re)Skin It" width: 200
		group "Skin Weights Computation" (
			spinner skin_falloff "Falloff" range:[0,1,0.5]
			button compute_skin_fast "Voxel" tooltip:"Fast skin computation but not so accurate" orient:#vertical  width: 100 across:2
			button compute_skin_slow "Heatmap" tooltip:"Slow skin computation but very accurate" orient:#vertical  width: 100 aligh:#right
		)

		group "Selected Verts Weight" (
			button weight_one "1" width: 40 across:5
			button scale_weights_up "+" width: 40
			button blend_weights "<->" width: 40
			button scale_weights_down "-" width: 40
			button weight_zero "0" width: 40
			button weights_mirror "Mirror" width: 200
		)

		group "Load Skin Checker Animations" (
			button load_test_animation1 "1" width: 100 across:2
			button load_test_animation2 "2" width: 100
		)

		on clean_model pressed do (
			cleanModel()
		)
		
		on draw_position_plane changed state do (
			if ($Position_Plane != undefined) then (
				delete $Position_Plane
				return 0
			)

			_plane = Plane length:250 width:100 transform:(matrix3 [1,0,0] [0,0,1] [0,-1,0] [0,0,100]) isSelected:on
			_plane.name = "Position_Plane"
			freeze _plane
			_plane.showFrozenInGray = false
			_plane.wirecolor = color 108 8 136
		)

		on delete_position_plane pressed do (
			if $Position_Plane != undefined do delete $Position_Plane
		)

		on skin_it pressed do (
			skinIt()
		)
		
		on blend_weights pressed do (
				skinOps.blendSelected $.modifiers[#Skin]
		)	
		
		
		on scale_weights_up pressed do (
			skinOps.scaleWeight $.modifiers[#Skin] 1.1
		)		
				
		
		on weight_one pressed do (
			skinOps.setWeight $.modifiers[#Skin] 1
		)			
		
		
		on weight_zero pressed do (
			skinOps.setWeight $.modifiers[#Skin] 0
		)		
		

		on scale_weights_down pressed do (
			skinOps.scaleWeight $.modifiers[#Skin] 0.9
		)	
		
		
		on weights_mirror pressed do (
			$.modifiers[#Skin].mirrorEnabled = on
			skinOps.pasteAllVerts $.modifiers[#Skin] off
			$.modifiers[#Skin].mirrorEnabled = off
		)

	
		on compute_skin_fast pressed do (
			computeSkin(false)
		)

		on compute_skin_slow pressed do (
			computeSkin(true)
		)
		
		on load_test_animation1 pressed do (
			deleteAllAnimation()
			currentDir = pathConfig.removePathLeaf (getSourceFileName()) as string
			biped.loadBipFile $Bip.controller (currentDir + "\\assets\\test-anim1.bip")
		)
		
		on load_test_animation2 pressed do (
			deleteAllAnimation()
			currentDir = pathConfig.removePathLeaf (getSourceFileName()) as string
			biped.loadBipFile $Bip.controller (currentDir + "\\assets\\test-anim2.bip")
		)


		on skin_falloff changed value do (
			setSetting "Skin_Falloff" (value as string)
		)

		on panel_model open do (
			value = getSetting "Skin_Falloff"
			if (value == undefined or value == "") then (
				value = 0.5f
			) else (
				value = value as float
			)

			skin_falloff.value = value
		)

	)


	rollout panel_animation "Animation" rolledup:true (
		group "Motion Root" (
			label _1 "Position" across:4 width: 50 offset:[0,3]
			checkbutton mr_xpos "X" orient:#vertical width:50 checked:true tooltip:"Track X Position" 
			checkbutton mr_ypos "Y" orient:#vertical width:50 checked:true tooltip:"Track Y Position"
			checkbutton mr_zpos "Z" orient:#vertical width:50 checked:false tooltip:"Track Z Position"
			
			/*
			label _2 "Rotation" across:4 width: 50 offset:[0,3]
			checkbutton mr_xrot "X" orient:#vertical width:50 checked:false tooltip:"Track X Rotation"
			checkbutton mr_yrot "Y" orient:#vertical width:50 checked:false tooltip:"Track Y Rotation"
			checkbutton mr_zrot "Z" orient:#vertical width:50 checked:true tooltip:"Track Z Rotation"
			*/

			button track_and_apply "Track and Apply" orient:#vertical width:200
			button btn_restore_anim "Restore" orient:#vertical width:200
		)

		button btn_delete_animation "Delete Animation" width:200

		on track_and_apply pressed do (
			extractMotion()
		)

		on btn_restore_anim pressed do (
			restore_anim()
		)
		
		on btn_delete_animation pressed do (
			deleteAllAnimation()
		)
	)


	rollout panel_export "Import and Export" rolledup:true (
		button incremental_save "Incremental Save" width:200
		label _1 "Export Path" offset:[0,3] width: 200
		EditText export_path ""  across:2 orient:#vertical width:175 offset:[0,3]
		button btn_export_path_browse "..." orient:#vertical width:25 align:#right

		label _2 "Prefix for Meshes" across:2 offset:[0,3] width: 100
		EditText txt_meshes_prefix "" width:100
		button btn_export_meshes "Export Meshes" width:200
		button btn_export_animations "Export Animations" width:200
		group "Sockets" (
			button create_sockets "Create" width:100 across:2
			button delete_sockets "Delete" width:100
		)

		group "Skeletal Mesh Export" (
			EditText txt_skeletal_mesh_name "Name:" width:200
			Checkbox chk_remove_additional_meshes "Remove Socket Meshes" width:200 checked:true
			button btn_export_skeletal_mesh "Export" width:200
		)
		
		fn saveAssetFolder = (
		)

		on btn_export_meshes pressed do (
			export_meshes()
		)		
		
		on btn_export_skeletal_mesh pressed do (
			export_skeletal_mesh()
		)

		on btn_export_path_browse pressed do (
			savePath = getSavePath caption:"Select Asset Folder" initialDir:(getPathAsset(""))
			if (savePath != undefined) then (
				export_path.text = savePath
				setSetting "Path_Asset" savePath
			)
		)

		on export_path entered txt do (
			setSetting "Path_Asset" txt
		)

		on panel_export open do (
			savePath = getSetting "Path_Asset"
			export_path.text = savePath
			txt_skeletal_mesh_name.text = detectMeshName()
		)

		on incremental_save pressed do (
			max saveplus
		)

		on btn_export_animations pressed do (
			export_animations()
		)	
		
		on create_sockets pressed do (
			createSockets()
		)

		on delete_sockets pressed do (
			deleteAllSockets()
		)

	)


	rollout panel_about "About" rolledup:false (
		label _11 "Author:" width:200
		label _14 "Behnam Aghajani" width:200 offset:[20,0]
		label _31 "behnam.a@gmail.com" width:200 offset:[20,0]

		label _16 "" width:200
		label _15 "Product:" width:200
		hyperLink _21 "Github Repo" width:140 color:(color 255 255 0) visitedColor:(color 255 255 0) address:"https://github.com/dexise/3dsMax-Asset-Tools-for-Unreal-Engine" offset:[20,0]
		hyperLink _41 "License: GNU GPLv3" width:140 color:(color 255 255 0) visitedColor:(color 255 255 0) address:"https://github.com/dexise/3dsMax-Asset-Tools-for-Unreal-Engine/blob/master/LICENSE" offset:[20,0]

		timer clock "refresh" interval:200

		button reload "Reload Script" width:100 across:2
		checkbutton show_info "Toggle Info" width:100 checked:true

		on reload pressed do (
			disable_info()
			fileIn "script.ms"
		)

		on get_class pressed do (
			cls = (classOf $) as string
			messagebox cls
		)

		on show_info changed state do (
			if state == on then (
				enable_info()
			) else (
  				disable_info()
			)
		)

		on clock tick do (
			if ($Bip == undefined) then (
				panel_biped.figure_mode.enabled = false
				panel_biped.copy_right_to_left.enabled = false
				panel_biped.copy_selected_right_to_left.enabled = false
				panel_biped.create_biped.enabled = true
				panel_biped.t_pose.enabled = false
				panel_biped.a_pose.enabled = false
				panel_biped.b_pose.enabled = false

				panel_hide_freeze.bone_hide_left.enabled = false
				panel_hide_freeze.bone_hide_center.enabled = false
				panel_hide_freeze.bone_hide_right.enabled = false
				panel_hide_freeze.bone_unhide.enabled = false

				panel_model.skin_it.enabled = false
				panel_model.load_test_animation1.enabled = false
				panel_model.load_test_animation2.enabled = false

				panel_animation.mr_xpos.enabled = false
				panel_animation.mr_ypos.enabled = false
				panel_animation.mr_zpos.enabled = false
				panel_animation._1.enabled = false
				/*
				panel_animation.mr_xrot.enabled = false
				panel_animation.mr_yrot.enabled = false
				panel_animation.mr_zrot.enabled = false
				panel_animation._2.enabled = false
				*/
				panel_animation.track_and_apply.enabled = false
				panel_animation.btn_delete_animation.enabled = false
				panel_animation.btn_restore_anim.enabled = false

				panel_biped.rename_to_ue4.enabled = false
				panel_biped.rename_to_biped.enabled = false
				panel_biped.rename_to_mixamo.enabled = false
			) else (
				panel_biped.figure_mode.enabled = true
				panel_biped.figure_mode.checked = $Bip.controller.figureMode
				panel_biped.copy_right_to_left.enabled = true
				panel_biped.copy_selected_right_to_left.enabled = true
				panel_biped.create_biped.enabled = false
				panel_biped.t_pose.enabled = true
				panel_biped.a_pose.enabled = true
				panel_biped.b_pose.enabled = true

				panel_hide_freeze.bone_hide_left.enabled = true
				panel_hide_freeze.bone_hide_center.enabled = true
				panel_hide_freeze.bone_hide_right.enabled = true
				panel_hide_freeze.bone_unhide.enabled = true

				panel_model.skin_it.enabled = true
				panel_model.compute_skin_fast.enabled = true
				panel_model.compute_skin_slow.enabled = true
				panel_model.load_test_animation1.enabled = true
				panel_model.load_test_animation2.enabled = true

				panel_animation.mr_xpos.enabled = true
				panel_animation.mr_ypos.enabled = true
				panel_animation.mr_zpos.enabled = true
				panel_animation._1.enabled = true
				/*
				panel_animation.mr_xrot.enabled = true
				panel_animation.mr_yrot.enabled = true
				panel_animation.mr_zrot.enabled = true
				panel_animation._2.enabled = true
				*/
				panel_animation.track_and_apply.enabled = true
				panel_animation.btn_delete_animation.enabled = true
				panel_animation.btn_restore_anim.enabled = true

				panel_biped.rename_to_ue4.enabled = true
				panel_biped.rename_to_biped.enabled = true
				panel_biped.rename_to_mixamo.enabled = true
			)

			if ($Position_Plane == undefined) then (
				panel_model.draw_position_plane.checked = false
			) else (
				panel_model.draw_position_plane.checked = true
			)

			panel_model.clean_model.enabled = true

			if ($ != undefined and isGeometry($) and (containsModifier $ Skin) and $Bip != undefined) then (
				panel_model.compute_skin_fast.enabled = true
				panel_model.compute_skin_slow.enabled = true
				panel_model.skin_falloff.enabled = true
				panel_model.weight_one.enabled = true
				panel_model.weight_zero.enabled = true
				panel_model.scale_weights_down.enabled = true
				panel_model.scale_weights_up.enabled = true
				panel_model.weights_mirror.enabled = true
				panel_model.blend_weights.enabled = true
			) else (
				panel_model.compute_skin_fast.enabled = false
				panel_model.compute_skin_slow.enabled = false
				panel_model.skin_falloff.enabled = false
				panel_model.weight_one.enabled = false
				panel_model.weight_zero.enabled = false
				panel_model.scale_weights_down.enabled = false
				panel_model.scale_weights_up.enabled = false
				panel_model.weights_mirror.enabled = false
				panel_model.blend_weights.enabled = false
			)

			if (panel_export.export_path.text != "") then (
				panel_export.txt_meshes_prefix.enabled = true
				panel_export.btn_export_meshes.enabled = true
				panel_export.btn_export_animations.enabled = true
				panel_export.btn_export_skeletal_mesh.enabled = true
				panel_export.chk_remove_additional_meshes.enabled = true
				panel_export.txt_skeletal_mesh_name.enabled = true
			) else (
				panel_export.txt_meshes_prefix.enabled = false
				panel_export.btn_export_meshes.enabled = false
				panel_export.btn_export_animations.enabled = false
				panel_export.btn_export_skeletal_mesh.enabled = false
				panel_export.chk_remove_additional_meshes.enabled = false
				panel_export.txt_skeletal_mesh_name.enabled = false
			)

			if (panel_export.txt_skeletal_mesh_name.text == "") then (
				panel_export.txt_skeletal_mesh_name.text = detectMeshName()
			)
		)
	)


	if (ui == undefined or ui.visible == false) then (
		ui = newRolloutFloater "Dexise Tools" 240 300 2195 750
		cui.RegisterDialogBar ui minSize:1 maxSize:-1 style:#(#cui_dock_left, #cui_dock_vert, #cui_floatable, #cui_max_sized)
	)


	rollouts = #(
		panel_hide_freeze,
		panel_biped,
		panel_model,
		panel_animation,
		panel_export,
		panel_about
	)


	for i in rollouts do (
		addRollout i ui
	)
)

(
	disable_info()
	makeUi()
	enable_info()
)
-- This file is simply the lua version of index.ts
-- All credits go to rbxts for creating this

local function averageNumbers(numbers)
	local count = #numbers
	if count == 0 then
		return 0
	end
	local _arg0 = function(acc, cv)
		return acc + cv
	end
	-- ▼ ReadonlyArray.reduce ▼
	local _result = 0
	local _callback = _arg0
	for _i = 1, #numbers do
		_result = _callback(_result, numbers[_i], _i - 1, numbers)
	end
	-- ▲ ReadonlyArray.reduce ▲
	return _result / count
end
--[[
	*
	* A type used to represent the parameters for scaling
]]
--[[
	*
	* A class used to represent the parameters for scaling
]]
local ScaleSpecifier
do
	ScaleSpecifier = setmetatable({}, {
		__tostring = function()
			return "ScaleSpecifier"
		end,
	})
	ScaleSpecifier.__index = ScaleSpecifier
	function ScaleSpecifier.new(...)
		local self = setmetatable({}, ScaleSpecifier)
		return self:constructor(...) or self
	end
	function ScaleSpecifier:constructor(_scaleInput)
		self._scaleInput = _scaleInput
		local inputType = typeof(_scaleInput)
		self.isNumber = inputType == "number"
		self.isVector2 = inputType == "Vector2"
		self.isVector3 = inputType == "Vector3"
		self.isScaleSpec = not (self.isNumber or (self.isVector2 or self.isVector3))
		if self.isNumber then
			local scaleNumber = self._scaleInput
			self.asNumber = scaleNumber
			self.asVector2 = Vector2.new(scaleNumber, scaleNumber)
			self.asVector3 = Vector3.new(scaleNumber, scaleNumber, scaleNumber)
			self.asScaleSpec = self
		elseif self.isVector2 then
			local scaleVec2 = self._scaleInput
			self.asNumber = averageNumbers({ scaleVec2.X, scaleVec2.Y })
			self.asVector2 = scaleVec2
			self.asVector3 = Vector3.new(scaleVec2.X, scaleVec2.Y, self.asNumber)
			self.asScaleSpec = self
		elseif self.isVector3 then
			local scaleVec3 = self._scaleInput
			self.asNumber = averageNumbers({ scaleVec3.X, scaleVec3.Y, scaleVec3.Z })
			self.asVector2 = Vector2.new(scaleVec3.X, scaleVec3.Y)
			self.asVector3 = scaleVec3
			self.asScaleSpec = self
		elseif self.isScaleSpec then
			local scaleSpec = self._scaleInput
			self.asNumber = scaleSpec.asNumber
			self.asVector2 = scaleSpec.asVector2
			self.asVector3 = scaleSpec.asVector3
			self.asScaleSpec = scaleSpec
		end
	end
end
--[[
	*
	* Scale a Model and all descendants uniformly
	* @param model The Model to scale
	* @param scale The amount to scale.  > 1 is bigger, < 1 is smaller
	* @param center (Optional) The point about which to scale.  Default: the Model's PrimaryPart's Position
]]
local _centerToOrigin, scaleDescendants
local function scaleModel(model, scale, center)
	if scale == 1 then
		return nil
	end
	local origin
	if center and typeof(center) == "Vector3" then
		origin = center
	else
		local pPart = model.PrimaryPart
		if not pPart then
			print("Unable to scale model, no center nor PrimaryPart has been defined")
			return nil
		end
		origin = _centerToOrigin(center, model:GetExtentsSize(), pPart.Position)
	end
	scaleDescendants(model, scale, origin)
end
--[[
	*
	* Scale a Part and all descendants uniformly
	* @param part The Part to scale
	* @param scale The amount to scale.  > 1 is bigger, < 1 is smaller
	* @param center (Optional) The point about which to scale.  Default: the Part's Position
]]
local _scaleBasePart
local function scalePart(part, scale, center)
	if scale == 1 then
		return nil
	end
	local origin = _centerToOrigin(center, part.Size, part.Position)
	_scaleBasePart(part, scale, origin)
	scaleDescendants(part, scale, origin)
end
local function lerpVector(vector, center, sspec)
	local delta = vector - center
	-- const {X, Y, Z} = vector;
	local centerX = center.X
	local centerY = center.Y
	local centerZ = center.Z
	local scaleVec = sspec.asVector3
	local scaleX = scaleVec.X
	local scaleY = scaleVec.Y
	local scaleZ = scaleVec.Z
	return Vector3.new(centerX + (delta.X * scaleX), centerY + (delta.Y * scaleY), centerZ + (delta.Z * scaleZ))
end
--[[
	*
	* Scale a Vector uniformly
	* @param vector The Vector to scale
	* @param scale The amount to scale.  > 1 is bigger, < 1 is smaller
	* @param center (Optional) The point about which to scale.  Default: position not considered
]]
local function scaleVector(vector, scale, center)
	if scale == 1 then
		return vector
	end
	local sspec = ScaleSpecifier.new(scale)
	if center then
		return lerpVector(vector, center, sspec)
	else
		local _result
		if sspec.isVector3 then
			local _asVector3 = sspec.asVector3
			_result = vector * _asVector3
		else
			local _asNumber = sspec.asNumber
			_result = vector * _asNumber
		end
		return _result
	end
end
--[[
	*
	* Scale an Explosion uniformly
	* @param explosion The Explosion to scale
	* @param scale The amount to scale.  > 1 is bigger, < 1 is smaller
]]
local function scaleExplosion(explosion, scale)
	if scale == 1 then
		return nil
	end
	local sspec = ScaleSpecifier.new(scale)
	local _result
	if sspec.isVector3 then
		local _position = explosion.Position
		local _asVector3 = sspec.asVector3
		_result = _position * _asVector3
	else
		local _position = explosion.Position
		local _asNumber = sspec.asNumber
		_result = _position * _asNumber
	end
	explosion.Position = _result
	explosion.BlastPressure = explosion.BlastPressure * sspec.asNumber
	explosion.BlastRadius = explosion.BlastRadius * sspec.asNumber
end
--[[
	*
	* Scale a Tool uniformly
	* @param tool The Tool to scale
	* @param scale The amount to scale.  > 1 is bigger, < 1 is smaller
	* @param center (Optional) The point about which to scale.  Default: the Tool's Handle's Position
]]
local function scaleTool(tool, scale, center)
	if scale == 1 then
		return nil
	end
	local origin
	if center and typeof(center) == "Vector3" then
		origin = center
	else
		local handle = tool:FindFirstChild("Handle")
		if not handle then
			print("Unable to scale tool, no center nor Handle has been defined")
			return nil
		end
		origin = _centerToOrigin(center, handle.Size, handle.Position)
	end
	scaleDescendants(tool, scale, origin)
end
local function disableWelds(container)
	local welds = {}
	local desc = container:GetDescendants()
	for _, instance in ipairs(desc) do
		if instance:IsA("WeldConstraint") then
			local _enabled = instance.Enabled
			-- ▼ Map.set ▼
			welds[instance] = _enabled
			-- ▲ Map.set ▲
			instance.Enabled = false
		end
	end
	return welds
end
local function enableWelds(welds)
	local _arg0 = function(value, wc)
		wc.Enabled = value
	end
	-- ▼ ReadonlyMap.forEach ▼
	for _k, _v in pairs(welds) do
		_arg0(_v, _k, welds)
	end
	-- ▲ ReadonlyMap.forEach ▲
end

local _scaleAttachment, _scaleMesh, _scaleFire, _scaleParticle, scaleTexture
function scaleDescendants(container, scale, origin, recur)
	if recur == nil then
		recur = false
	end
	if scale == 1 then
		return nil
	end
	local _result
	if recur then
		_result = nil
	else
		_result = disableWelds(container)
	end
	local welds = _result
	local instances = container:GetChildren()
	for _, instance in ipairs(instances) do
		local scaledChildren = false
		if instance:IsA("BasePart") then
			_scaleBasePart(instance, scale, origin)
		elseif instance:IsA("Model") then
			scaleModel(instance, scale, origin)
			scaledChildren = true
		elseif instance:IsA("Attachment") then
			_scaleAttachment(instance, scale, origin)
		elseif instance:IsA("Tool") then
			scaleTool(instance, scale, origin)
			scaledChildren = true
		elseif instance:IsA("SpecialMesh") then
			_scaleMesh(instance, scale, origin)
		elseif instance:IsA("Fire") then
			_scaleFire(instance, scale, origin)
		elseif instance:IsA("Explosion") then
			scaleExplosion(instance, scale)
		elseif instance:IsA("ParticleEmitter") then
			_scaleParticle(instance, scale)
		elseif instance:IsA("Texture") then
			scaleTexture(instance, scale, origin)
        elseif instance:IsA('JointInstance') then
            local c0NewPos = instance.C0.Position * scale
			local c0RotX, c0RotY, c0RotZ = instance.C0:ToEulerAnglesXYZ()
			
			local c1NewPos = instance.C1.Position * scale
			local c1RotX, c1RotY, c1RotZ = instance.C1:ToEulerAnglesXYZ()

			instance.C0 = CFrame.new(c0NewPos) * CFrame.Angles(c0RotX, c0RotY, c0RotZ)
			instance.C1 = CFrame.new(c1NewPos) * CFrame.Angles(c1RotX, c1RotY, c1RotZ)
		end
		if not scaledChildren then
			scaleDescendants(instance, scale, origin, true)
		end
	end
	if welds then
		enableWelds(welds)
	end
end
function scaleTexture(texture, scale, origin)
	local sspecV2 = ScaleSpecifier.new(scale).asVector2
	texture.OffsetStudsU = texture.OffsetStudsU * sspecV2.X
	texture.OffsetStudsV = texture.OffsetStudsV * sspecV2.Y
	texture.StudsPerTileU = texture.StudsPerTileU * sspecV2.X
	texture.StudsPerTileV = texture.StudsPerTileV * sspecV2.Y
end
local _minSide
function _centerToOrigin(center, size, position)
	local origin
	if typeof(center) == "Vector3" then
		origin = center
	else
		if center then
			origin = _minSide(size, position, center)
		else
			origin = position
		end
	end
	return origin
end
function _minSide(size, position, side)
	local halfSize = size * 0.5
	repeat
		if side == (Enum.NormalId.Front) then
			return Vector3.new(position.X, position.Y, position.Z - halfSize.Z)
		end
		if side == (Enum.NormalId.Back) then
			return Vector3.new(position.X, position.Y, position.Z + halfSize.Z)
		end
		if side == (Enum.NormalId.Right) then
			return Vector3.new(position.X + halfSize.X, position.Y, position.Z)
		end
		if side == (Enum.NormalId.Left) then
			return Vector3.new(position.X - halfSize.X, position.Y, position.Z)
		end
		if side == (Enum.NormalId.Top) then
			return Vector3.new(position.X, position.Y + halfSize.Y, position.Z)
		end
		if side == (Enum.NormalId.Bottom) then
			return Vector3.new(position.X, position.Y - halfSize.Y, position.Z)
		end
	until true
	return position
end
function _scaleBasePart(part, scale, origin)
	local _cFrame = part.CFrame
	local _position = part.Position
	local angle = _cFrame - _position
	local sspec = ScaleSpecifier.new(scale)
	local pos = lerpVector(part.Position, origin, sspec)
	local _result
	if sspec.isVector3 then
		local _size = part.Size
		local _asVector3 = sspec.asVector3
		_result = _size * _asVector3
	else
		local _size = part.Size
		local _asNumber = sspec.asNumber
		_result = _size * _asNumber
	end
	part.Size = _result
	part.CFrame = CFrame.new(pos) * angle
end

function _scaleAttachment(attachment, scale, _origin)
	local parent = attachment:FindFirstAncestorWhichIsA("BasePart")
	if parent then
		attachment.WorldPosition = lerpVector(attachment.WorldPosition, parent.Position, ScaleSpecifier.new(scale))
	end
end
function _scaleMesh(mesh, scale, _origin)
	local _scale = mesh.Scale
	local _asNumber = ScaleSpecifier.new(scale).asNumber
	mesh.Scale = _scale * _asNumber
end
function _scaleFire(fire, scale, _origin)
	fire.Size = math.floor(fire.Size * ScaleSpecifier.new(scale).asNumber)
end
local _scaleNumberSequence
function _scaleParticle(particle, scale)
	particle.Size = _scaleNumberSequence(particle.Size, scale)
end
function _scaleNumberSequence(sequence, scale)
	local scaleNum = ScaleSpecifier.new(scale).asNumber
	local _keypoints = sequence.Keypoints
	local _arg0 = function(kp)
		return NumberSequenceKeypoint.new(kp.Time, kp.Value * scaleNum, kp.Envelope * scaleNum)
	end
	-- ▼ ReadonlyArray.map ▼
	local _newValue = table.create(#_keypoints)
	for _k, _v in ipairs(_keypoints) do
		_newValue[_k] = _arg0(_v, _k - 1, _keypoints)
	end
	-- ▲ ReadonlyArray.map ▲
	return NumberSequence.new(_newValue)
end

return {
    ['averageNumbers'] = averageNumbers,
    ['scaleSpecifier'] = scaleSpecifier,
    ['scaleModel'] = scaleModel,
    ['scalePart'] = scalePart,
    ['lerpVector'] = lerpVector,
    ['scaleVector'] = scaleVector,
    ['scaleExplosion'] = scaleExplosion,
    ['scaleTool'] = scaleTool,
    ['disableWelds'] = disableWelds,
    ['enableWelds'] = enableWelds,
    ['scaleDescendants'] = scaleDescendants,
    ['scaleTexture'] = scaleTexture,
    ['centerToOrigin'] = _centerToOrigin,
    ['minSide'] = _minSide,
    ['scaleBasePart'] = _scaleBasePart,
    ['scaleAttachment'] = _scaleAttachment,
    ['scaleMesh'] = _scaleMesh,
    ['scaleFire'] = _scaleFire,
    ['scaleParticle'] = _scaleParticle,
    ['scaleNumberSequence'] = _scaleNumberSequence
}

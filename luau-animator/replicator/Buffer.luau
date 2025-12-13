--!strict

-- Buffer
-- magicoal_nerb :3

local Buffer = {}
Buffer.__index = Buffer

export type Buffer = typeof(setmetatable({} :: {
	data: buffer,
	size: number,
	cursor: number
}, Buffer))

function Buffer.write(capacity: number): Buffer
	-- Creates a writable buffer
	return setmetatable({
		size = capacity,
		data = buffer.create(capacity),
		cursor = 0,
	}, Buffer)
end

function Buffer.read(data: buffer): Buffer
	-- Creates a readable buffer
	return setmetatable({
		size = buffer.len(data),
		data = data,
		cursor = 0,
	}, Buffer)
end

function Buffer.empty(self: Buffer): boolean
	return self.size == 1
end

function Buffer.eof(self: Buffer): boolean
	-- Returns whether the cursor is outside of the
	-- file :P
	return self.size <= self.cursor
end

function Buffer.allocate(self: Buffer, count: number)
	if self.cursor + count < self.size then
		-- No need to reallocate the buffer because
		-- we are below its size
		return
	end

	-- Recreate the buffer and copy the contents over
	local newSize = 2 * (self.cursor + count)
	local newData = buffer.create(newSize)
	buffer.copy(newData, 0, self.data, 0, self.size)

	-- Finalize state
	self.data = newData
	self.size = newSize
end

function Buffer.setCursor(self: Buffer, cursor: number)
	-- Sets cursor
	self.cursor = cursor
end

function Buffer.getData(self: Buffer): buffer
	-- Returns the internal buffer
	local output = buffer.create(self.cursor)
	buffer.copy(output, 0, self.data, 0, self.cursor)
	
	return output
end

function Buffer.writeColor3(self: Buffer, color: Color3)
	-- Writes a Color3 into the buffer
	self:writeU8(color.R * 255)
	self:writeU8(color.G * 255)
	self:writeU8(color.B * 255)
end

function Buffer.readColor3(self: Buffer): Color3
	-- Reads a Color3 from the buffer
	return Color3.fromRGB(
		self:readU8(),
		self:readU8(),
		self:readU8()
	)
end

function Buffer.writeBrickColor(self: Buffer, brickcolor: BrickColor)
	-- Writes a BrickColor into the buffer
	self:writeU8(brickcolor.Number)
end

function Buffer.readBrickColor(self: Buffer): BrickColor
	-- Reads a BrickColor from the buffer
	return BrickColor.new(self:readU8())
end

function Buffer.writeBoolean(self: Buffer, bool: boolean)
	-- Writes a boolean from the buffer
	return self:writeU8(bool and 1 or 0)
end

function Buffer.readBoolean(self: Buffer): boolean
	-- Reads a boolean from the buffer
	return self:readU8() == 1
end

function Buffer.writeCFrame(self: Buffer, cframe: CFrame)
	-- Writes the position and quaternion equivalent
	-- of the CFrame
	self:allocate(28)

	local x, y, z, m11, m12, m13, m21, m22, m23, m31, m32, m33 = cframe:GetComponents()
	local qw, qx, qy, qz

	if m11 + m22 + m33 > 0 then
		qw = math.sqrt(1 + m11 + m22 + m33) * 0.5
		qx = (m32-m23) / (4*qw)
		qy = (m13-m31) / (4*qw)
		qz = (m21-m12) / (4*qw)
	elseif m11 > m22 and m11 > m33 then
		qx = math.sqrt(1 + m11 - m22 - m33) * 0.5
		qy = (m21+m12) / (4*qx)
		qz = (m31+m13) / (4*qx)
		qw = (m32-m23) / (4*qx)
	elseif m22 > m33 then
		qy = math.sqrt(1 + m22 - m11 - m33) * 0.5
		qx = (m21+m12) / (4*qy)
		qz = (m32+m23) / (4*qy)
		qw = (m13-m31) / (4*qy)
	else
		qz = math.sqrt(1 + m33 - m11 - m22) * 0.5
		qx = (m31+m13) / (4*qz)
		qy = (m32+m23) / (4*qz)
		qw = (m21-m12) / (4*qz)
	end

	local cursor = self.cursor
	local data = self.data

	buffer.writef32(data, cursor, x)
	buffer.writef32(data, cursor + 4, y)
	buffer.writef32(data, cursor + 8, z)
	buffer.writef32(data, cursor + 12, qx)
	buffer.writef32(data, cursor + 16, qy)
	buffer.writef32(data, cursor + 20, qz)
	buffer.writef32(data, cursor + 24, qw)

	self.cursor += 28
end

function Buffer.readCFrame(self: Buffer): CFrame
	-- Reads a CFrame from the buffer
	local cursor = self.cursor
	local data = self.data

	self.cursor += 28
	return CFrame.new(
		buffer.readf32(data, cursor),
		buffer.readf32(data, cursor + 4),
		buffer.readf32(data, cursor + 8),

		buffer.readf32(data, cursor + 12),
		buffer.readf32(data, cursor + 16),
		buffer.readf32(data, cursor + 20),
		buffer.readf32(data, cursor + 24)
	)
end

function Buffer.writeBuffer(self: Buffer, data: buffer)
	-- Get the length of the buffer
	local len = buffer.len(data)
	self:allocate(len)
	
	-- Copy its contents to the data stream
	buffer.copy(self.data, self.cursor, data)
	self.cursor += len
end

function Buffer.writeVector3(self: Buffer, vec: Vector3)
	-- Writes a Vector3 into the buffer
	self:allocate(12)

	local cursor = self.cursor
	local data = self.data

	buffer.writef32(data, cursor, vec.X)
	buffer.writef32(data, cursor + 4, vec.Y)
	buffer.writef32(data, cursor + 8, vec.Z)

	self.cursor += 12
end

function Buffer.readVector3(self: Buffer): Vector3
	-- Reads a Vector3 from the buffer
	local cursor = self.cursor
	local data = self.data

	self.cursor += 12
	return Vector3.new(
		buffer.readf32(data, cursor),
		buffer.readf32(data, cursor + 4),
		buffer.readf32(data, cursor + 8)
	)
end

function Buffer.writeFloat(self: Buffer, float: number)
	-- Writes a float into the buffer
	self:allocate(4)

	buffer.writef32(self.data, self.cursor, float)
	self.cursor += 4
end

function Buffer.readFloat(self: Buffer): number
	-- Reads a float from the buffer
	self.cursor += 4
	return buffer.readf32(self.data, self.cursor - 4)
end

function Buffer.writeU32(self: Buffer, uint: number)
	-- Writes an unsigned integer into the buffer
	self:allocate(4)

	buffer.writeu32(self.data, self.cursor, uint)
	self.cursor += 4
end

function Buffer.readU32(self: Buffer): number
	-- Reads an unsigned integer from the buffer
	self.cursor += 4
	return buffer.readu32(self.data, self.cursor - 4)
end

function Buffer.writeU16(self: Buffer, uint: number)
	-- Writes a short into the buffer
	self:allocate(2)

	buffer.writeu16(self.data, self.cursor, uint)
	self.cursor += 2
end

function Buffer.readU16(self: Buffer): number
	-- Reads a short from the buffer
	self.cursor += 2
	return buffer.readu16(self.data, self.cursor - 2)
end

function Buffer.writeEnum(self: Buffer, enum: EnumItem)
	-- Writes a byte into the buffer
	self:allocate(1)

	buffer.writeu8(self.data, self.cursor, enum.Value)
	self.cursor += 1
end

function Buffer.readEnum(self: Buffer)
	-- Reads a byte from the buffer
	self.cursor += 1
	return buffer.readu8(self.data, self.cursor - 1)
end

function Buffer.writeU8(self: Buffer, uint: number)
	-- Writes a byte into the buffer
	self:allocate(1)

	buffer.writeu8(self.data, self.cursor, uint)
	self.cursor += 1
end

function Buffer.readU8(self: Buffer): number
	-- Reads a byte from the buffer
	self.cursor += 1
	return buffer.readu8(self.data, self.cursor - 1)
end

function Buffer.writeString(self: Buffer, str: string)
	-- Writes a null-terminated string into the buffer
	local length = #str
	local cursor = self.cursor
	local data = self.data

	self:allocate(length)

	buffer.writestring(self.data, cursor, str, length)
	buffer.writeu8(self.data, cursor + length, 0)

	self.cursor += length + 1
end

function Buffer.readString(self: Buffer): string
	local cursor = self.cursor
	local start = cursor
	local data = self.data

	while cursor < self.size and buffer.readu8(data, cursor) ~= 0 do
		-- Keep on going right until we find a null byte
		-- or reach the end of the buffer
		cursor += 1
	end

	self.cursor = cursor + 1
	return buffer.readstring(self.data, start, cursor - start)
end

return Buffer
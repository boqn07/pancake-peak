--!strict
-- Zone geometry: which zone a point is on, ramps, landmarks and the Yeti tables.
-- Pure data/math so the server, the client and tests all agree on where everything is.
local Zones = require(script.Parent.Parent.Config.Zones)

local ZoneGeo = {}

export type Yeti = { index: number, x: number, y: number, z: number, faceX: number, faceZ: number }

-- Unit vector (x, z) from the zone center toward Base Camp: the side the ramp arrives on.
function ZoneGeo.towardHub(zoneId: string): (number, number)
	local c = Zones.ById[zoneId].center
	local len = math.sqrt(c.x * c.x + c.z * c.z)
	return -c.x / len, -c.z / len
end

-- Zone id at a world position, or nil (Base Camp, ramps, clouds).
function ZoneGeo.zoneAt(x: number, y: number, z: number): string?
	for _, zone in Zones.List do
		local dx, dz = x - zone.center.x, z - zone.center.z
		if dx * dx + dz * dz <= zone.radius * zone.radius and y > zone.center.y - 10 and y < zone.center.y + 80 then
			return zone.id
		end
	end
	return nil
end

-- The ramp of a zone: from Base Camp's edge to the zone's edge, with heights at both ends.
function ZoneGeo.ramp(zoneId: string): {
	ax: number,
	az: number,
	ay: number,
	bx: number,
	bz: number,
	by: number,
	length: number,
}
	local zone = Zones.ById[zoneId]
	local ux, uz = ZoneGeo.towardHub(zoneId)
	local hub = Zones.Hub
	local ax, az = -ux * (hub.radius - 4), -uz * (hub.radius - 4)
	local bx, bz = zone.center.x + ux * (zone.radius - 4), zone.center.z + uz * (zone.radius - 4)
	return {
		ax = ax,
		az = az,
		ay = hub.center.y,
		bx = bx,
		bz = bz,
		by = zone.center.y,
		length = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2),
	}
end

-- True when (x, z) is on solid ground: Base Camp, a zone or a ramp.
function ZoneGeo.onLand(x: number, z: number): boolean
	local hub = Zones.Hub
	if x * x + z * z <= (hub.radius + 2) ^ 2 then
		return true
	end
	for _, zone in Zones.List do
		local dx, dz = x - zone.center.x, z - zone.center.z
		if dx * dx + dz * dz <= (zone.radius + 2) ^ 2 then
			return true
		end
		local ux, uz = ZoneGeo.towardHub(zone.id)
		local along = -(x * ux + z * uz)
		local across = math.abs(x * uz - z * ux)
		local len = math.sqrt(zone.center.x ^ 2 + zone.center.z ^ 2)
		if along >= 0 and along <= len and across <= Zones.RampWidth / 2 + 2 then
			return true
		end
	end
	return false
end

-- Landmarks: where the ramp lands (entrance), the Mystery Egg (to one side of the entrance), the
-- spawn point when teleporting in, and the plaza in the middle.
function ZoneGeo.landmarks(zoneId: string): {
	entrance: { x: number, z: number },
	egg: { x: number, z: number },
	spawn: { x: number, z: number },
	plaza: { x: number, z: number },
}
	local zone = Zones.ById[zoneId]
	local c = zone.center
	local ux, uz = ZoneGeo.towardHub(zoneId)
	local px, pz = -uz, ux
	local edge = zone.radius - 8
	return {
		entrance = { x = c.x + ux * edge, z = c.z + uz * edge },
		egg = { x = c.x + ux * (zone.radius * 0.62) + px * 26, z = c.z + uz * (zone.radius * 0.62) + pz * 26 },
		spawn = { x = c.x + ux * (zone.radius - 18), z = c.z + uz * (zone.radius - 18) },
		plaza = { x = c.x, z = c.z },
	}
end

-- The Yeti tables: three on a ring around the plaza, away from the entrance, each facing the center.
-- Yeti i (1..3) craves the Stack.CravingBands[i] band (low, mid, high).
local yetiCache: { [string]: { Yeti } } = {}
function ZoneGeo.yetis(zoneId: string): { Yeti }
	local cached = yetiCache[zoneId]
	if cached then
		return cached
	end
	local zone = Zones.ById[zoneId]
	local ux, uz = ZoneGeo.towardHub(zoneId)
	local base = math.atan2(uz, ux)
	local ring = zone.radius * Zones.YetiRing
	local out: { Yeti } = {}
	local n = Zones.YetisPerZone
	for i = 1, n do
		-- Spread from 90° to 270° away from the entrance direction.
		local a = base + math.rad(90 + (i - 1) * (180 / math.max(1, n - 1)))
		local x = zone.center.x + math.cos(a) * ring
		local z = zone.center.z + math.sin(a) * ring
		table.insert(out, {
			index = i,
			x = x,
			y = zone.center.y,
			z = z,
			faceX = -math.cos(a),
			faceZ = -math.sin(a),
		})
	end
	yetiCache[zoneId] = out
	return out
end

-- Nearest Yeti of a zone to a point (and its horizontal distance).
function ZoneGeo.nearestYeti(zoneId: string, x: number, z: number): (Yeti, number)
	local best, bestD = nil, math.huge
	for _, y in ZoneGeo.yetis(zoneId) do
		local d = math.sqrt((y.x - x) ^ 2 + (y.z - z) ^ 2)
		if d < bestD then
			best, bestD = y, d
		end
	end
	return best :: Yeti, bestD
end

return ZoneGeo

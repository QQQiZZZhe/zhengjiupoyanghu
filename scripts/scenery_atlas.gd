extends RefCounted
## Keep source pixels/regions intact while allowing depth-sorted sprites to
## share a GPU texture. Built once after the seasonal artwork is prepared.
var regions: Dictionary = {}
var pages: Array[Texture2D] = []

func build(sources: Array) -> void:
	var unique: Array[Texture2D] = []
	var seen := {}
	for source in sources:
		if source == null or seen.has(source.get_instance_id()): continue
		seen[source.get_instance_id()] = true
		unique.append(source)
	unique.sort_custom(func(a, b): return a.get_height() > b.get_height())
	var placements: Array = []
	var x := 2
	var y := 2
	var row_height := 0
	var width := 2048
	for source in unique: width = maxi(width, source.get_width() + 4)
	for source in unique:
		var extent: Vector2i = source.get_size()
		if x + extent.x + 2 > width:
			x = 2
			y += row_height + 4
			row_height = 0
		placements.append({"source": source, "rect": Rect2i(Vector2i(x, y), extent)})
		x += extent.x + 4
		row_height = maxi(row_height, extent.y)
	var image := Image.create(width, y + row_height + 2, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for placement in placements:
		var original: Image = placement.source.get_image()
		if original.is_compressed(): original.decompress()
		if original.get_format() != Image.FORMAT_RGBA8: original.convert(Image.FORMAT_RGBA8)
		image.blit_rect(original, Rect2i(Vector2i.ZERO, original.get_size()), placement.rect.position)
	var page := ImageTexture.create_from_image(image)
	pages.append(page)
	for placement in placements:
		var region := AtlasTexture.new()
		region.atlas = page
		region.region = Rect2(placement.rect)
		region.filter_clip = true
		regions[placement.source.get_instance_id()] = region

func texture(source: Texture2D) -> Texture2D:
	return regions.get(source.get_instance_id(), source)

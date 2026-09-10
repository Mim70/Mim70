extends SceneTree
func _initialize():
 var data=var_to_bytes([{1:[Vector3.ONE,Vector2.ZERO,[]]},{},{"epoch":0},{},{}]).compress(FileAccess.COMPRESSION_GZIP)
 var decoded=bytes_to_var(data.decompress_dynamic(1048576,FileAccess.COMPRESSION_GZIP))
 assert(decoded is Array and decoded.size()==5)
 print("CODEC_PASS")
 quit()

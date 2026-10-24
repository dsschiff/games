extends SceneTree
var checks := 0
var failures: Array[String] = []
func check(value: bool, description: String) -> void:
    checks += 1
    if not value:
        failures.append(description)
        printerr("FAIL: "+description)
func _initialize() -> void:
    var options := {}
    for arg in OS.get_cmdline_user_args():
        var pair := arg.split("=",true,1)
        if pair.size()==2: options[pair[0]]=pair[1]
    var backup: GDScript=load(get_script().resource_path.get_base_dir().path_join("../cloud_backup.gd"))
    var store: GDScript=load(options["--decoder"])
    var validate := func(raw: String) -> Dictionary: return store.decode(raw)
    var file_path: String=options["--save-file"]
    var package_id: String=options["--package"]
    var original:=FileAccess.get_file_as_string(file_path)
    var expected: Dictionary=validate.call(original)
    check(expected.get("ok",false),"Owning real decoder accepts representative app-written save")
    if expected.get("ok",false):
        var packet: Dictionary=backup.encode(package_id,original,validate)
        check(packet.get("ok",false),"Validated complete real save encodes")
        if packet.get("ok",false):
            var restored: Dictionary=backup.decode(package_id,packet.text,validate)
            check(restored.get("ok",false) and restored.save==original,"Opaque save retains every exact UTF-8 byte")
            check(restored.get("ok",false) and restored.decoded==expected,"Complete decoded context including parked and earned fields retained")
            check(not backup.decode(package_id+".other",packet.text,validate).ok,"Package binding rejects another game")
            var future: Dictionary=JSON.parse_string(original)
            var inner: Dictionary=JSON.parse_string(future.payload) if future.has("payload") else future.duplicate(true)
            var key: String="schema" if inner.has("schema") else "version"
            check(inner.has(key),"Representative save exposes owning schema version")
            inner[key]=99999
            if future.has("payload"):
                future.payload=JSON.stringify(inner)
                future.sha256=String(future.payload).sha256_text()
            else: future=inner
            var future_text:=JSON.stringify(future)
            check(not validate.call(future_text).get("ok",false),"Real decoder rejects future schema even with recomputed inner checksum")
            var forged: Dictionary=JSON.parse_string(packet.text)
            forged.save=future_text
            forged.sha256=future_text.sha256_text()
            check(not backup.decode(package_id,JSON.stringify(forged),validate).ok,"Recomputed transport checksum cannot bypass owning schema validation")
            check(not backup.encode(package_id,future_text,validate).ok,"Future-schema save cannot be staged for upload")
    check(FileAccess.get_file_as_string(file_path)==original,"Validation never mutates source save")
    var report:={"package":package_id,"checks":checks,"failures":failures,"save_file":file_path,"save_sha256":original.sha256_text(),"decoder":options["--decoder"],"decoder_sha256":FileAccess.get_file_as_string(options["--decoder"]).sha256_text(),"codec_sha256":FileAccess.get_file_as_string(backup.resource_path).sha256_text(),"scope":"Local opaque-envelope and real owning-decoder checks on representative app-written records. No native plugin, account, network, game UI, restore commit or cloud/device acceptance."}
    FileAccess.open(options["--report"],FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("REAL_SAVE_BINDING ",package_id," ",checks," failures=",failures.size())
    print("SUITE_COMPLETE: ","PASS" if failures.is_empty() else "FAIL")
    quit(0 if failures.is_empty() else 1)

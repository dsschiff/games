extends RefCounted
const Content = preload("res://scripts/campaign_data.gd")
const Profile = preload("res://scripts/campaign_profile.gd")

static func buttons(game: Variant) -> Dictionary:
	var result := {"mute": Rect2(238, 65, 104, 46), "effects": Rect2(352, 65, 110, 46), "save": Rect2(472, 65, 108, 46), "resume_run": Rect2(20, 916, 270, 80), "practice": Rect2(310, 916, 270, 80)}
	if game.screen == "ending":
		result["journey"] = Rect2(60, 700, 480, 90)
		result["challenges"] = Rect2(60, 810, 480, 90)
	elif game.screen == "challenges":
		for i in 3:
			result["challenge%d" % i] = Rect2(40, 270 + i * 180, 520, 140)
		result["journey"] = Rect2(40, 830, 520, 80)
	else:
		for i in 9:
			result["mission%d" % i] = Rect2(20 + (i % 3) * 190, 254 + (i / 3) * 202, 180, 148)
		if Content.IDS.back() in game.profile.cleared:
			result["challenges"] = Rect2(20, 856, 560, 50)
	return result

static func draw(game: Variant) -> void:
	game.draw_rect(Rect2(0, 0, 600, 1066), Color("10212c"))
	game.label_at("GEAR BASTION", Vector2(20, 37), 28, game.GOLD)
	var ui := buttons(game)
	for key in ["mute", "effects", "save"]:
		game.panel(ui[key], Color("243c48"))
		game.label_at(("Muted" if game.settings.muted else "Sound on") if key == "mute" else ("Calm FX" if game.settings.reduced_effects else "Full FX") if key == "effects" else "Save", ui[key].get_center() + Vector2(0, 7), 17, game.CREAM, true)
	var medals := 0
	for value in game.profile.medals.values():
		medals += int(value)
	if game.screen == "ending":
		game.label_at("THE FOUNDRIES ARE AWAKE", Vector2(300, 231), 30, game.MINT, true)
		game.label_at("The tide breaks at the brass gates.", Vector2(300, 307), 23, game.CREAM, true)
		game.label_at("Your crews carry the heart home.", Vector2(300, 348), 23, game.CREAM, true)
		for i in 3:
			game.panel(Rect2(82 + i * 150, 425, 136, 150), Color("344b50"), game.GOLD)
			game.draw_circle(Vector2(150 + i * 150, 473), 24, game.GOLD)
			game.label_at(str(i + 1), Vector2(150 + i * 150, 536), 34, game.CREAM, true)
		game.label_at("9 gates defended · %d / 27 medals" % medals, Vector2(300, 639), 22, game.GOLD, true)
		for key in ["journey", "challenges"]:
			game.panel(ui[key], Color("304754"), game.MINT)
			game.label_at("Revisit the journey" if key == "journey" else "Seeded trials", ui[key].get_center() + Vector2(0, 8), 25, game.CREAM, true)
		return
	if game.screen == "challenges":
		game.label_at("SEEDED TRIALS", Vector2(300, 188), 30, game.MINT, true)
		game.label_at("New seeds · budgets reduced by 6", Vector2(300, 224), 21, game.CREAM, true)
		for i in 3:
			var id: String = ["camp_05", "camp_07", "camp_09"][i]
			game.panel(ui["challenge%d" % i], Color("223c48"), game.GOLD)
			game.label_at(Content.NAMES[Content.IDS.find(id)], ui["challenge%d" % i].get_center() - Vector2(0, 17), 26, game.CREAM, true)
			var key := id + ":" + str(1729 + i)
			var earned: int = game.profile.challenge_clears.get(key, 0)
			game.label_at("Seed %d · %s" % [1729 + i, "◆".repeat(earned) if earned > 0 else "uncleared"], ui["challenge%d" % i].get_center() + Vector2(0, 25), 19, game.MINT, true)
		game.panel(ui.journey, Color("304754"))
		game.label_at("Back to journey", ui.journey.get_center() + Vector2(0, 8), 24, game.CREAM, true)
		return
	game.label_at("THE THREE FOUNDRIES", Vector2(300, 173), 28, game.MINT, true)
	game.label_at("%d / 9 defended · %d / 27 medals" % [game.profile.cleared.size(), medals], Vector2(300, 208), 21, game.CREAM, true)
	for act in 3:
		game.label_at(["I · BRASS QUAY", "II · SHALE FOUNDRY", "III · THE CITADEL"][act], Vector2(20, 240 + act * 202), 18, game.GOLD)
	for i in 9:
		var id: String = Content.IDS[i]
		var box: Rect2 = ui["mission%d" % i]
		var accessible := Profile.accessible(game.profile, id)
		game.panel(box, Color("25414d") if accessible else Color("1b2d38"), game.MINT if id in game.profile.cleared else Color.TRANSPARENT)
		game.label_at("%02d" % (i + 1), box.get_center() + Vector2(0, -34), 28, game.GOLD if accessible else Color("77858a"), true)
		var title: String = Content.NAMES[i]
		var words := title.split(" ")
		var first := " ".join(words.slice(0, 2))
		var rest := " ".join(words.slice(2))
		game.label_at(first, box.get_center() + Vector2(0, 0), 19, game.CREAM, true)
		game.label_at(rest, box.get_center() + Vector2(0, 24), 19, game.CREAM, true)
		game.label_at(("◆".repeat(int(game.profile.medals.get(id, 0)))) if id in game.profile.cleared else "Prepare" if accessible else "Locked", box.get_center() + Vector2(0, 54), 18, game.MINT, true)
	if ui.has("challenges"):
		game.panel(ui.challenges, Color("304754"))
		game.label_at("Seeded trials unlocked", ui.challenges.get_center() + Vector2(0, 7), 21, game.MINT, true)
	for key in ["resume_run", "practice"]:
		game.panel(ui[key], Color("304754"), game.GOLD if key == "resume_run" else Color.TRANSPARENT)
		game.label_at("Resume defense" if key == "resume_run" else "Practice foundry", ui[key].get_center() + Vector2(0, 8), 22, game.CREAM, true)
	game.label_at("Clear a foundry to open the next. No grinding required.", Vector2(300, 1034), 18, game.CREAM, true)

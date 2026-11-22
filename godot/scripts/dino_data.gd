class_name DinoData
## Everything the game says about each animal. `model` is filled in from assets/models/dinos/<id>.glb
## (only species with a model file appear in the jungle). Lengths are real adult sizes in metres.
## kind: walk / fly / swim. home: plains, lake, forest, river, volcano, coast, sea.

const ALL := {
	"trex": {
		"name": "T. rex", "say": "Tyrannosaurus rex",
		"length": 12.0, "speed": 3.5, "kind": "walk", "diet": "meat", "home": "forest", "herd": 1, "count": 2, "biped": true, "hip": 0.45,
		"facts": [
			"T. rex was one of the biggest meat-eating dinosaurs ever!",
			"Its teeth were as big as bananas!",
			"T. rex had tiny arms, but a giant head and a super strong bite.",
		],
	},
	"triceratops": {
		"name": "Triceratops", "say": "Triceratops",
		"length": 9.0, "speed": 3.0, "kind": "walk", "diet": "plants", "home": "plains", "herd": 4, "count": 2,
		"facts": [
			"Triceratops had three horns on its face. Tri means three!",
			"It had a big bony frill around its neck, like a shield.",
			"Triceratops ate plants with its beak, like a giant parrot.",
		],
	},
	"stegosaurus": {
		"name": "Stegosaurus", "say": "Stegosaurus",
		"length": 9.0, "speed": 2.5, "kind": "walk", "diet": "plants", "home": "plains", "herd": 3, "count": 2,
		"facts": [
			"Stegosaurus had big plates on its back and spikes on its tail.",
			"Its brain was only as big as a lemon!",
			"Stegosaurus swung its spiky tail to keep meat-eaters away.",
		],
	},
	"velociraptor": {
		"name": "Velociraptor", "say": "Velociraptor",
		"length": 2.0, "speed": 4.5, "kind": "walk", "diet": "meat", "home": "forest", "herd": 3, "count": 2, "biped": true, "hip": 0.5,
		"facts": [
			"Velociraptor was about as big as a turkey, and it had feathers!",
			"It had a big curved claw on each foot.",
			"Velociraptor was fast and smart and hunted in the bushes.",
		],
	},
	"apatosaurus": {
		"name": "Apatosaurus", "say": "Apatosaurus",
		"length": 22.0, "speed": 2.0, "kind": "walk", "diet": "plants", "home": "lake", "herd": 3, "count": 2,
		"facts": [
			"Apatosaurus had a super long neck and a long whip tail.",
			"It was as long as two school buses!",
			"Apatosaurus ate leaves all day long to fill its giant tummy.",
		],
	},
	"brachiosaurus": {
		"name": "Brachiosaurus", "say": "Brachiosaurus",
		"length": 22.0, "speed": 2.0, "kind": "walk", "diet": "plants", "home": "lake", "herd": 2, "count": 2, "hip": 0.3,
		"facts": [
			"Brachiosaurus was as tall as a four story building!",
			"Its front legs were longer than its back legs, like a giraffe.",
			"It ate leaves from the very tops of the trees.",
		],
	},
	"diplodocus": {
		"name": "Diplodocus", "say": "Diplodocus",
		"length": 26.0, "speed": 2.0, "kind": "walk", "diet": "plants", "home": "lake", "herd": 2, "count": 2,
		"facts": [
			"Diplodocus was one of the longest dinosaurs ever!",
			"It could crack its long tail like a whip.",
			"Diplodocus had teeth like a comb to rake off leaves.",
		],
	},
	"parasaurolophus": {
		"name": "Parasaurolophus", "say": "Parasaurolophus",
		"length": 10.0, "speed": 3.5, "kind": "walk", "diet": "plants", "home": "river", "herd": 4, "count": 2,
		"facts": [
			"Parasaurolophus had a long tube on its head.",
			"It could blow through its crest to make loud honking sounds!",
			"It walked on two legs or four, and ate plants.",
		],
	},
	"ankylosaurus": {
		"name": "Ankylosaurus", "say": "Ankylosaurus",
		"length": 7.0, "speed": 1.5, "kind": "walk", "diet": "plants", "home": "plains", "herd": 2, "count": 2,
		"facts": [
			"Ankylosaurus was covered in bony armor, like a tank!",
			"It had a big club at the end of its tail.",
			"Ankylosaurus was low and wide and munched on short plants.",
		],
	},
	"spinosaurus": {
		"name": "Spinosaurus", "say": "Spinosaurus",
		"length": 15.0, "speed": 3.0, "kind": "walk", "diet": "fish", "home": "river", "herd": 1, "count": 2,
		"facts": [
			"Spinosaurus had a giant sail on its back.",
			"It loved the water and caught big fish!",
			"Spinosaurus was even longer than T. rex.",
		],
	},
	"pachycephalosaurus": {
		"name": "Pachycephalosaurus", "say": "Pachy-cephalo-saurus",
		"length": 4.5, "speed": 4.0, "kind": "walk", "diet": "plants", "home": "forest", "herd": 3, "count": 2,
		"facts": [
			"Pachycephalosaurus had a super thick dome on its head.",
			"Its skull was as thick as a big book!",
			"It may have bonked heads with its friends.",
		],
	},
	"iguanodon": {
		"name": "Iguanodon", "say": "Iguanodon",
		"length": 10.0, "speed": 3.0, "kind": "walk", "diet": "plants", "home": "plains", "herd": 4, "count": 2,
		"facts": [
			"Iguanodon had a big spike on each thumb!",
			"It was one of the very first dinosaurs people ever found.",
			"Iguanodon ate plants and lived in big groups.",
		],
	},
	"dilophosaurus": {
		"name": "Dilophosaurus", "say": "Dilophosaurus",
		"length": 7.0, "speed": 5.0, "kind": "walk", "diet": "meat", "home": "forest", "herd": 1, "count": 2,
		"facts": [
			"Dilophosaurus had two thin crests on its head.",
			"Its name means two crested lizard.",
			"Dilophosaurus was a fast meat-eater.",
		],
	},
	"allosaurus": {
		"name": "Allosaurus", "say": "Allosaurus",
		"length": 9.5, "speed": 5.0, "kind": "walk", "diet": "meat", "home": "forest", "herd": 1, "count": 2,
		"facts": [
			"Allosaurus was a big meat-eater with little horns over its eyes.",
			"It lived long before T. rex.",
			"Allosaurus had sharp teeth like knives.",
		],
	},
	"gallimimus": {
		"name": "Gallimimus", "say": "Gallimimus",
		"length": 6.0, "speed": 8.0, "kind": "walk", "diet": "plants", "home": "plains", "herd": 5, "count": 1,
		"facts": [
			"Gallimimus looked like a big ostrich!",
			"It was one of the fastest dinosaurs.",
			"Gallimimus had no teeth, just a beak.",
		],
	},
	"compsognathus": {
		"name": "Compsognathus", "say": "Compsognathus",
		"length": 1.0, "speed": 6.0, "kind": "walk", "diet": "meat", "home": "coast", "herd": 4, "count": 2,
		"facts": [
			"Compsognathus was as small as a chicken!",
			"It ate lizards and bugs.",
			"It was tiny but very fast.",
		],
	},
	"pteranodon": {
		"name": "Pteranodon", "say": "Pteranodon",
		"length": 5.0, "speed": 1.4, "kind": "walk", "diet": "fish", "home": "coast", "herd": 3, "count": 2,
		"head_z": 1.0, "hip": 0.45,
		"facts": [
			"Pteranodon was not a dinosaur. It was a flying reptile!",
			"Its wings were as wide as a car is long.",
			"On the beach, Pteranodon folded its wings and walked on all fours.",
		],
	},
	"pterodactyl": {
		"name": "Pterodactyl", "say": "Pterodactyl",
		"length": 1.5, "speed": 9.0, "kind": "fly", "diet": "fish", "home": "volcano", "herd": 3, "count": 2,
		"facts": [
			"Pterodactyls were flying reptiles, not dinosaurs!",
			"Their wings were made of skin stretched over one long finger.",
			"They flew around catching fish and bugs.",
		],
	},
	"protoceratops": {
		"name": "Protoceratops", "say": "Protoceratops",
		"length": 2.5, "speed": 3.0, "kind": "walk", "diet": "plants", "home": "plains", "herd": 4, "count": 2,
		"facts": [
			"Protoceratops was about as big as a sheep.",
			"It had a little frill on its neck and a beak like a parrot.",
			"Protoceratops laid its eggs in nests in the sand.",
		],
	},
	"shark": {
		"name": "Shark", "say": "Shark",
		"length": 5.0, "speed": 5.0, "kind": "swim", "diet": "fish", "home": "sea", "herd": 1, "count": 3,
		"head_z": 1.0, "tail_amp": 3.0,
		"facts": [
			"Sharks swam in the sea even before the dinosaurs!",
			"Sharks grow new teeth all their lives.",
			"A shark's skin feels like sandpaper.",
		],
	},
	"crocodile": {
		"name": "Crocodile", "say": "Crocodile",
		"length": 6.0, "speed": 1.2, "kind": "walk", "diet": "meat", "home": "river", "herd": 1, "count": 3,
		"head_z": 1.0, "hip": 0.55, "tail_amp": 1.5,
		"facts": [
			"Crocodiles lived at the same time as the dinosaurs!",
			"A crocodile can hold its breath under water for a long time.",
			"Crocodiles have super strong jaws and lots of teeth.",
		],
	},
	"mosasaurus": {
		"name": "Mosasaurus", "say": "Mosasaurus",
		"length": 15.0, "speed": 5.0, "kind": "swim", "diet": "fish", "home": "sea", "herd": 1, "count": 2,
		"facts": [
			"Mosasaurus was a giant sea reptile, not a dinosaur.",
			"It swam with flippers and a big tail.",
			"Mosasaurus was the king of the ocean!",
		],
	},
	"plesiosaurus": {
		"name": "Plesiosaurus", "say": "Plesiosaurus",
		"length": 4.0, "speed": 4.0, "kind": "swim", "diet": "fish", "home": "sea", "herd": 2, "count": 1,
		"facts": [
			"Plesiosaurus had a long neck and four big flippers.",
			"It swam in the sea and ate fish.",
			"It came up to the top of the water to breathe air.",
		],
	},
}


## Map a model filename to a species id ("Velociraptor_Animated.glb" -> "velociraptor").
static func id_for_file(file: String) -> String:
	var f := file.to_lower()
	var aliases := {"tyrannosaurus": "trex", "t-rex": "trex", "t_rex": "trex", "raptor": "velociraptor",
		"brontosaurus": "apatosaurus", "stego": "stegosaurus", "trike": "triceratops", "ptera": "pteranodon",
		"parasaur": "parasaurolophus", "ankylo": "ankylosaurus", "spino": "spinosaurus", "pachy": "pachycephalosaurus",
		"dilopho": "dilophosaurus", "mosa": "mosasaurus", "plesio": "plesiosaurus", "compy": "compsognathus",
		"brachio": "brachiosaurus", "diplo": "diplodocus", "allo": "allosaurus", "galli": "gallimimus", "iguano": "iguanodon"}
	for id in ALL:
		if f.contains(id):
			return id
	for k in aliases:
		if f.contains(k):
			return aliases[k]
	if f.contains("trex") or f.contains("rex"):
		return "trex"
	return ""

package main

import (
	"encoding/json"
	"testing"
)

// Exact shipped catalog, independently exercised at the wire-format boundary.
var m129Operators = []string{
	"aak",
	"amiya",
	"angelina",
	"archetto",
	"bagpipe",
	"blaze",
	"blemishine",
	"blue_poison",
	"carnelian",
	"ceobe",
	"chen",
	"chen_alter",
	"cliffheart",
	"cuora",
	"dusk",
	"elysium",
	"eunectes",
	"exusiai",
	"eyjafjalla",
	"eyjafjalla_alter",
	"feater",
	"fiammetta",
	"flametail",
	"gavial_alter",
	"gitano",
	"gladiia",
	"gnosis",
	"goldenglow",
	"gravel",
	"gummy",
	"haze",
	"hellagur",
	"horn",
	"hoshiguma",
	"ifrit",
	"ines",
	"istina",
	"jessica",
	"jessica_alter",
	"kaltsit",
	"lappland",
	"lee",
	"lin",
	"ling",
	"liskarm",
	"lumen",
	"magallan",
	"meteorite",
	"mizuki",
	"mlynar",
	"mon3tr_operator",
	"mostima",
	"mountain",
	"mudrock",
	"muelsyse",
	"myrtle",
	"nearl",
	"nian",
	"nightingale",
	"pallas",
	"passenger",
	"penance",
	"perfumer",
	"phantom",
	"platinum",
	"podenco",
	"pozyomka",
	"pramanix",
	"projekt_red",
	"ptilopsis",
	"reed_alter",
	"rosa",
	"saga",
	"saileach",
	"saria",
	"schwarz",
	"shamare",
	"shaw",
	"shining",
	"siege",
	"silence",
	"silence_alter",
	"silverash",
	"skadi",
	"skadi_alter",
	"skyfire",
	"sora",
	"specter",
	"stainless",
	"surtr",
	"sussurro",
	"suzuran",
	"swire_alter",
	"texas",
	"texas_alter",
	"thorns",
	"titi",
	"typhon",
	"vigil",
	"w",
	"warfarin",
	"weedy",
	"wildmane",
	"zima",
}
var m129Summons = []string{
	"curse_doll",
	"dusk_freeling",
	"flowing_shape",
	"jessica_shield",
	"ling_soul1",
	"ling_soul2",
	"ling_soul3",
	"magallan_drone_a",
	"magallan_drone_f",
	"magallan_drone_l",
	"medical_drone",
	"mon3tr",
	"mon3tr_reconstruction",
	"nightingale_phantom",
	"phantom_clone",
	"pozyomka_typewriter",
	"seaborn",
	"silence_alter_drone",
	"stainless_cannon",
	"stainless_device_atk",
	"stainless_device_sp",
	"vigil_wolf",
	"weedy_cannon",
}

func TestM129CatalogCommands(t *testing.T) {
	if len(m129Operators) != 104 || len(m129Summons) != 23 {
		t.Fatal("catalog size")
	}
	seen := map[string]bool{}
	for _, group := range [][]string{m129Operators, m129Summons} {
		for _, id := range group {
			if seen[id] {
				t.Fatal("duplicate or overlapping ID", id)
			}
			seen[id] = true
			deploy := []any{6.0, 0.0, id, -1.0, 12.0, 5.0, -1.0, 0.0, -1.0}
			if !validCommands([][]any{deploy}, 6) {
				t.Fatal("registered deploy rejected", id)
			}
			for _, unknown := range []string{id + "_unknown", id + " ", "x_" + id} {
				deploy[2] = unknown
				if validCommands([][]any{deploy}, 6) {
					t.Fatal("near-match accepted", unknown)
				}
			}
		}
	}
	for _, id := range m129Operators {
		for facing := 0; facing < 4; facing++ {
			if !validCommands([][]any{{6.0, 4.0, id, 123456.0, 0.0, 0.0, -1.0, float64(facing), -1.0}}, 6) {
				t.Fatal("ordinary copy target rejected", id, facing)
			}
		}
	}
	for _, id := range m129Summons {
		if validCommands([][]any{{6.0, 4.0, id, 123456.0, 0.0, 0.0, -1.0, 0.0, -1.0}}, 6) {
			t.Fatal("summon copy target accepted", id)
		}
	}
}

func TestM129CatalogRelayPreservesIntent(t *testing.T) {
	_, url := setup(t)
	a, b, r, m := playing(t, url)
	var commands []any
	// The newly added ordinary units and summons fit in one bounded input batch.
	for _, id := range []string{"wildmane", "muelsyse", "mlynar", "gavial_alter", "eunectes", "jessica_alter", "goldenglow", "dusk", "chen_alter", "fiammetta", "titi", "mon3tr_operator", "stainless", "ling", "gladiia", "shaw"} {
		commands = append(commands, []any{6, 0, id, -1, 12, 5, -1, 0, -1})
		commands = append(commands, []any{6, 4, id, 987654, 0, 0, -1, 3, -1})
	}
	for _, id := range []string{"flowing_shape", "jessica_shield", "dusk_freeling", "mon3tr_reconstruction", "stainless_device_atk", "stainless_device_sp", "stainless_cannon", "ling_soul1", "ling_soul2", "ling_soul3"} {
		commands = append(commands, []any{6, 0, id, -1, 12, 5, -1, 2, -1})
	}
	input(a, r, m, 6, commands)
	got := b.read("input")
	expected, _ := json.Marshal(commands)
	actual, _ := json.Marshal(got["commands"])
	if string(expected) != string(actual) || got["side"] != float64(0) {
		t.Fatal("catalog input fields changed", string(actual))
	}
	input(b, r, m, 6, []any{})
	a.read("input")
}

func TestM129CatalogRelayRejectsSummonCopy(t *testing.T) {
	for _, id := range m129Summons {
		t.Run(id, func(t *testing.T) {
			_, url := setup(t)
			a, _, r, m := playing(t, url)
			input(a, r, m, 6, []any{[]any{6, 4, id, 123456, 0, 0, -1, 0, -1}})
			a.rejected()
		})
	}
}

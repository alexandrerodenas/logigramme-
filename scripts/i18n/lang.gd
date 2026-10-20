class_name Lang
extends RefCounted
## Langue de l'interface. Le français est la langue source : chaque texte affiché y passe par `t()`,
## qui renvoie la traduction anglaise de `Strings.EN` quand la langue est « en ».

static var code := "fr"


static func t(fr: String) -> String:
	if code == "en":
		return Strings.EN.get(fr, fr)
	return fr


## Choisit le texte selon la langue, pour les cas où les deux formes sont écrites à part.
static func tc(fr: String, en: String) -> String:
	return en if code == "en" else fr


static func is_en() -> bool:
	return code == "en"

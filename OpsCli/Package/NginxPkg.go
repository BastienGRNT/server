package Package

import (
	"OpsCli/Cmd"
	"OpsCli/Message"
)

func Nginx() {

	Message.Info("Vérification de Nginx...")

	if err := Cmd.NoOut("nginx -v"); err != nil {
		Message.Info("⚠️  Nginx non trouvé, installation en cours...")

		if err := Cmd.NoOut("yum -y -q install nginx && systemctl enable nginx && systemctl start nginx"); err != nil {

			Message.Clear()
			Message.Info("Échec de l’installation de Nginx : " + err.Error())
			return
		}

		Message.Clear()
		Message.Info("✅ Nginx installé et démarré.")
	} else {
		Message.Clear()
		Message.Info("✅ Nginx est déjà installé.")
	}
}

package Cmd

import "os/exec"

func NoOut(commande string) error {
	cmd := exec.Command("bash", "-lc", commande) // -lc : charge environnement
	cmd.Stdout, cmd.Stderr = nil, nil
	return cmd.Run()
}

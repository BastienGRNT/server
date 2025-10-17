package Message

import (
	"fmt"
	"os"
	"os/exec"
)

func Info(message string) {
	fmt.Printf("\033[34m%s\033[0m\n", message)
}

func Clear() {
	var cmd *exec.Cmd

	cmd = exec.Command("clear")

	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	_ = cmd.Run()
}

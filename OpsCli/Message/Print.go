package Message

import (
	"fmt"
	"os"
	"os/exec"
)

func Info(message string) {
	fmt.Println("\\033[34m" + message + "\\033[0m")
}

func Clear() {
	var cmd *exec.Cmd

	cmd = exec.Command("clear")

	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	_ = cmd.Run()
}

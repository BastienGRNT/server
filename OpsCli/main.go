package main

import (
	"OpsCli/Package"
	"fmt"

	"github.com/spf13/cobra"
)

func main() {
	// Commande racine (root)
	rootCmd := &cobra.Command{
		Use:   "OpsCli",
		Short: "CLI de test Cobra",
		Long:  "Petit CLI pour apprendre à utiliser la librairie Cobra",
	}

	// Sous-commande "test"
	testCmd := &cobra.Command{
		Use:   "test",
		Short: "Commande de test",
		Run: func(cmd *cobra.Command, args []string) {
			Package.Nginx()
		},
	}

	// Ajoute la sous-commande au root
	rootCmd.AddCommand(testCmd)

	// Exécute le CLI
	if err := rootCmd.Execute(); err != nil {
		fmt.Println("Erreur:", err)
	}
}

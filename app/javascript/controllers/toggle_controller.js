import { Controller } from "@hotwired/stimulus";
import JSConfetti from "js-confetti";

// Connects to data-controller="toggle"
export default class extends Controller {
  static targets = ["hideable", "show"];

  connect() {
    // console.log("Conectou no toggle controller stimulus");
    // console.log(this.hideableTarget);
    // console.log(this.showTarget);
  }

  call(event) {
    event.preventDefault();
    if (this.hideableTarget.classList.contains("d-none")) {
      this.hideableTarget.classList.remove("d-none");
      this.showTarget.classList.add("d-none");
    } else {
      this.hideableTarget.classList.add("d-none");
      this.showTarget.classList.remove("d-none");
      const jsConfetti = new JSConfetti();
      jsConfetti.addConfetti({
        emojis: ["🌈", "⚡️", "💥", "✨", "💫", "🌸"],
      });
      jsConfetti.addConfetti();
    }
  }
}

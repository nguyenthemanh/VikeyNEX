/** English contractions typed without the apostrophe. Same table as the Android keyboard. */
export class Contractions {
  private static table(low: string): string {
    if (low === 'dont') { return "don't"; }
    if (low === 'cant') { return "can't"; }
    if (low === 'isnt') { return "isn't"; }
    if (low === 'arent') { return "aren't"; }
    if (low === 'wasnt') { return "wasn't"; }
    if (low === 'werent') { return "weren't"; }
    if (low === 'doesnt') { return "doesn't"; }
    if (low === 'didnt') { return "didn't"; }
    if (low === 'hasnt') { return "hasn't"; }
    if (low === 'havent') { return "haven't"; }
    if (low === 'hadnt') { return "hadn't"; }
    if (low === 'couldnt') { return "couldn't"; }
    if (low === 'wouldnt') { return "wouldn't"; }
    if (low === 'shouldnt') { return "shouldn't"; }
    if (low === 'mustnt') { return "mustn't"; }
    if (low === 'neednt') { return "needn't"; }
    if (low === 'aint') { return "ain't"; }
    if (low === 'wouldve') { return "would've"; }
    if (low === 'couldve') { return "could've"; }
    if (low === 'shouldve') { return "should've"; }
    if (low === 'mightve') { return "might've"; }
    if (low === 'im') { return "I'm"; }
    if (low === 'ive') { return "I've"; }
    if (low === 'youre') { return "you're"; }
    if (low === 'youve') { return "you've"; }
    if (low === 'youll') { return "you'll"; }
    if (low === 'youd') { return "you'd"; }
    if (low === 'theyre') { return "they're"; }
    if (low === 'theyve') { return "they've"; }
    if (low === 'theyll') { return "they'll"; }
    if (low === 'theyd') { return "they'd"; }
    if (low === 'weve') { return "we've"; }
    if (low === 'itll') { return "it'll"; }
    if (low === 'thatll') { return "that'll"; }
    if (low === 'shes') { return "she's"; }
    if (low === 'thats') { return "that's"; }
    if (low === 'whats') { return "what's"; }
    if (low === 'wheres') { return "where's"; }
    if (low === 'theres') { return "there's"; }
    if (low === 'heres') { return "here's"; }
    if (low === 'hows') { return "how's"; }
    if (low === 'whos') { return "who's"; }
    if (low === 'whove') { return "who've"; }
    if (low === 'lets') { return "let's"; }
    if (low === 'yall') { return "y'all"; }
    if (low === 'i') { return 'I'; }
    if (low === 'wont') { return "won't"; }
    return '';
  }

  private static capitalOnly(low: string): string {
    if (low === 'ill') { return "I'll"; }
    if (low === 'id') { return "I'd"; }
    if (low === 'lets') { return "Let's"; }
    return '';
  }

  /** The fixed word, or an empty string when it should stay as typed. */
  static fix(typed: string): string {
    if (typed.length === 0) {
      return '';
    }
    const low = typed.toLowerCase();
    const capital = Contractions.capitalOnly(low);
    let out = '';
    if (capital.length > 0) {
      if (typed.charAt(0) !== typed.charAt(0).toUpperCase() || typed.charAt(0) === typed.charAt(0).toLowerCase()) {
        return '';
      }
      out = capital;
    } else {
      const mapped = Contractions.table(low);
      if (mapped.length === 0 || low === 'lets') {
        return '';
      }
      out = mapped;
    }
    if (typed.length > 1 && typed === typed.toUpperCase()) {
      out = out.toUpperCase();
    } else if (typed.charAt(0) === typed.charAt(0).toUpperCase() && typed.charAt(0) !== typed.charAt(0).toLowerCase()) {
      out = out.substring(0, 1).toUpperCase() + out.substring(1);
    }
    return out === typed ? '' : out;
  }
}

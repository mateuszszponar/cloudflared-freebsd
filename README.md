# OpenCode Smart Pipeline 🚀

Inteligentny pipeline kodowania dla OpenCode z automatycznym podziałem pracy między modele.

## Idea

**Problem:** Claude jest drogi, ale daje najlepsze wyniki. GLM jest tani, ale może nie planować tak dobrze.

**Rozwiązanie:** Użyj Claude tam gdzie ma to sens (planowanie), a GLM tam gdzie wystarczy (implementacja).

```
Twój prompt → DeepSeek (rozwija) → Claude (planuje) → GLM (koduje)
                 DARMOWY            NAJLEPSZY          TANI
```

## Szybki start

### 1. Zainstaluj OpenCode
```bash
npm install -g opencode-ai
```

### 2. Skonfiguruj klucze API
```bash
# DeepSeek - expansion (darmowy tier dostępny)
export DEEPSEEK_API_KEY="sk-..."

# Anthropic - planning (najważniejszy)
export ANTHROPIC_API_KEY="sk-ant-..."

# Zhipu GLM - coding (tani)
export ZHIPU_API_KEY="..."
```

### 3. Skopiuj konfigurację
```bash
# Do projektu
cp opencode.json /twój/projekt/
cp -r .opencode /twój/projekt/

# Lub globalnie
cp opencode.json ~/.config/opencode/
cp -r .opencode ~/.config/opencode/
```

### 4. Używaj!
```bash
cd /twój/projekt
opencode

# Po prostu pisz co chcesz zrobić
> dodaj system logowania z JWT
```

## Jak to działa?

### Etap 1: Expansion (DeepSeek)
Twój prosty prompt zostaje rozwinięty w szczegółową specyfikację:
- Analizuje strukturę projektu
- Identyfikuje istniejące wzorce
- Określa pliki do zmiany
- Definiuje wymagania i edge cases

### Etap 2: Planning (Claude → GLM fallback)
Specyfikacja trafia do planera który tworzy:
- Decyzje architektoniczne
- Kroki implementacji (atomowe, jasne)
- Podpowiedzi dla codera
- Strategię testowania

**Fallback:** Gdy Claude niedostępny (brak tokenów), automatycznie przełącza na GLM.

### Etap 3: Coding (GLM)
Coder wykonuje plan krok po kroku:
- Tworzy/modyfikuje pliki
- Instaluje zależności
- Raportuje postęp

## Komendy

| Komenda | Opis |
|---------|------|
| `/code <zadanie>` | Pełny pipeline z Claude |
| `/code-budget <zadanie>` | Pełny pipeline tylko GLM |
| `/quick <zadanie>` | Szybko, bez planowania |
| `/expand <zadanie>` | Tylko rozwiń prompt |
| `/plan <spec>` | Tylko zaplanuj (Claude) |
| `/plan-glm <spec>` | Tylko zaplanuj (GLM) |
| `/impl <plan>` | Tylko zaimplementuj |

## Przykłady

### Dodanie funkcji
```
> dodaj dark mode do aplikacji

🔄 Rozszerzam prompt...
🔄 Planuję implementację (Claude)...
🔄 Implementuję (GLM)...
✅ Gotowe!

📁 Utworzono: ThemeContext.tsx, ThemeToggle.tsx
📝 Zmodyfikowano: layout.tsx, tailwind.config.js
```

### Tryb budżetowy
```
> /code-budget napraw walidację emaila

🔄 Rozszerzam prompt...
🔄 Planuję implementację (GLM)...
🔄 Implementuję (GLM)...
✅ Gotowe!
```

### Szybka poprawka
```
> /quick zmień tytuł strony na "Moja Aplikacja"

🔄 Rozszerzam prompt...
🔄 Implementuję (GLM Flash)...
✅ Gotowe!
```

## Oszczędności

| Scenariusz | Tylko Claude | Ten pipeline | Oszczędność |
|------------|--------------|--------------|-------------|
| Prosty endpoint | ~$0.02 | ~$0.008 | 60% |
| Formularz z walidacją | ~$0.05 | ~$0.015 | 70% |
| System auth | ~$0.10 | ~$0.03 | 70% |

## Struktura plików

```
.
├── opencode.json              # Konfiguracja OpenCode
├── AGENTS.md                  # Instrukcje dla projektu
├── README.md                  # Ten plik
└── .opencode/
    └── agents/
        ├── orchestrator-prompt.md  # Orkiestrator
        ├── expander-prompt.md      # Expansion (DeepSeek)
        ├── planner-prompt.md       # Planning (Claude/GLM)
        └── coder-prompt.md         # Coding (GLM)
```

## Konfiguracja zaawansowana

### Zmiana modeli
W `opencode.json`:
```json
{
  "agent": {
    "expander": {
      "model": "deepseek/deepseek-chat"  // lub inny tani
    },
    "planner-claude": {
      "model": "anthropic/claude-sonnet-4-5-20250929"  // lub opus
    },
    "coder": {
      "model": "zhipu/glm-4"  // lub glm-4-flash
    }
  }
}
```

### Dostępne modele
```bash
opencode models  # Lista wszystkich
```

## FAQ

**P: Co jeśli nie mam klucza do Claude?**
O: Użyj `/code-budget` - wszystko pójdzie przez GLM.

**P: Czy mogę użyć innych modeli niż GLM?**
O: Tak! Zamień na Qwen, GPT-4o-mini, DeepSeek Coder, lub lokalny przez Ollama.

**P: Jak wyłączyć automatyczny fallback?**
O: Użyj `/plan` zamiast pełnego pipeline - wymusi Claude.

**P: Czy to działa z istniejącym projektem?**
O: Tak! Expander analizuje strukturę projektu i dostosowuje się.

## Troubleshooting

### "Provider not found"
```bash
opencode auth login  # Skonfiguruj klucze
```

### Claude zwraca błąd
System automatycznie przełączy na GLM. Sprawdź limity w konsoli Anthropic.

### Słaba jakość planów GLM
Dla krytycznych zadań użyj `/plan` z Claude, a potem `/impl` z planem.

---

Stworzono z myślą o oszczędnym kodowaniu 💰

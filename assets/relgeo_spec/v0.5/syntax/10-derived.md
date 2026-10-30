# 10. Derived Values

Status dokumen: `Normative`

Derived value adalah nilai yang dihitung secara otomatis dari ekspresi, parameter, constant, atau query geometri. Derived value bersifat **read-only** - tidak dapat di-assign secara langsung oleh pengguna.

---

## 10.1 Syntax

```rg
derived:
  panelWidth:
    value: totalWidth - margin * 2

  halfRadius:
    value: outerRadius / 2

  centerPt:
    value: panel.center
```

Shorthand syntax juga didukung (tanpa `value:`):

```rg
derived:
  panelWidth: totalWidth - margin * 2
```

---

## 10.2 Type Inference

Tipe hasil ditentukan dari hasil evaluasi ekspresi secara otomatis.

| Ekspresi | Tipe hasil |
|----------|------------|
| `diameter / 2` | `length` (jika `diameter` bertipe `length`) |
| `count * 1` | `number` |
| `panel.center` | `point` |
| `length(outline)` | `scalar-length` |

---

## 10.3 Dependency Rules

Derived value dapat bergantung pada:

- `parameters`
- `constants`
- derived lain (selama tidak melingkar)
- anchor object (misal `panel.center`, `line1.length`)
- hasil query geometri (misal `length(path)`, `distance(A, B)`)

Dependency melingkar tidak diperbolehkan dan akan menghasilkan error `CIRCULAR_DEPENDENCY`.

---

## 10.4 Usage

Derived value dapat digunakan di mana pun ekspresi diterima:

```rg
objects:
  innerRect:
    type: rect
    size: [panelWidth, panelWidth]
    place:
      center: panel.center
```

---

## 10.5 Local Derived in Components

Dalam kontrak aktif v0.5, component juga boleh memiliki `derived` lokal.

Contoh:

```rg
components:
  bracket:
    parameters:
      width:
        type: length
      thickness:
        type: length
    derived:
      innerRadius: thickness * 1.5
      holeOffset: width / 4
    objects:
      hole:
        type: circle
        center: [holeOffset, 0mm]
        radius: innerRadius
```

Aturan minimum:

1. `derived` lokal hanya dapat diakses di dalam component yang sama
2. ia dievaluasi setelah parameter component di-resolve
3. ia boleh dipakai oleh object internal component
4. ia juga boleh dipakai oleh `exports` component bila diperlukan
5. jika ada konflik nama dengan `derived` global, scope component memprioritaskan `derived` lokal

Catatan:

1. `derived` lokal tidak menjadi simbol global dokumen
2. perilaku read-only tetap sama seperti `derived` global

---

[← 9. Constants](09-constants.md) &nbsp;|&nbsp; [↑ Index](README.md) &nbsp;|&nbsp; [11. Profiles →](11-profiles.md)

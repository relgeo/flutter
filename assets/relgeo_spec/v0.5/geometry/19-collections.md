# 19. Collections

Status dokumen: `Normative`

Collection adalah kumpulan object runtime.

Collection berbeda dengan array.

---

## 19.1 Array

Array adalah data statis.

```rg
constants:
  values:
    - 1
    - 2
    - 3
```

---

## 19.2 Collection

Collection adalah kumpulan object hasil runtime.

Contoh sumber collection:

```txt
repeat
divide
multi-result boolean
multi-result intersection
```

---

## 19.3 Collection Access

```rg
derived:
  firstCenter: holes[0].center
```

---

## 19.4 Collection Functions

### count

```rg
count(holes)
```

Menghasilkan:

```txt
number
```

---

### first

```rg
first(holes)
```

Menghasilkan object pertama.

---

### last

```rg
last(holes)
```

Menghasilkan object terakhir.

---

## 19.5 Collection Ordering

Collection wajib memiliki urutan yang stabil.

Input yang sama harus menghasilkan urutan collection yang sama.

Hal ini diperlukan untuk:

- repeat identity
- deterministic intersection
- collection indexing
- reproducible rendering

---

[← 18. Anchors](18-anchors.md) &nbsp;|&nbsp; [↑ Index](README.md) &nbsp;|&nbsp; [20. Geometry Queries →](20-geometry-queries.md)

function isValidSignatureCanvas (data) {
  // Alleen controleren of er iets is getekend (niet leeg)
  // Geen validatie op complexiteit of grootte
  return data.length > 0
}

export { isValidSignatureCanvas }

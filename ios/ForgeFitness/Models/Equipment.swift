enum Equipment: String, CaseIterable, Identifiable, Hashable {
    case barbell = "Barbell"
    case trapBar = "Trap Bar"
    case bench = "Bench"
    case pullUpBar = "Pull-Up Bar"
    case landmine = "Landmine"
    case dumbbells = "Dumbbells"
    case cableMachine = "Cable Machine"
    case sled = "Sled"
    case plyoBox = "Plyo Box"
    case bodyweight = "Bodyweight"

    var id: Self { self }
}

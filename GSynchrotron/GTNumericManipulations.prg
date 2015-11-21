'' Returns angle in degrees in the range [lowerBound, upperBound)
Function GTBoundAngle(lowerBound As Real, upperBound As Real, Angle As Real) As Real
	Do While (Angle < lowerBound)
	  Angle = Angle + 360
	Loop

	Do While (Angle >= upperBound)
	  Angle = Angle - 360
	Loop

	GTBoundAngle = Angle
Fend



Function GTAngleToPerfectOrientationAngle(Angle As Real) As Real
	'' BoundAngle to [0,360)
	Angle = GTBoundAngle(0, 360, Angle)
	
	Integer OrientationIndex
	OrientationIndex = Int(Angle / 90.0 + 0.5)
	
	GTAngleToPerfectOrientationAngle = OrientationIndex * 90.0
	
Fend


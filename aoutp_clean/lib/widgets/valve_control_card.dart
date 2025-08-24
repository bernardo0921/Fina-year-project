import 'package:flutter/material.dart';

class ValveControlCard extends StatelessWidget {
  final String valveName;
  final bool isActive;
  final IconData icon;
  final Color color;
  final VoidCallback onToggle;

  const ValveControlCard({
    super.key,
    required this.valveName,
    required this.isActive,
    required this.icon,
    required this.color,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isActive ? 4 : 2,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: isActive 
                ? Border.all(color: color, width: 2)
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isActive 
                      ? color.withOpacity(0.1)
                      : Color(0xFFF8F9FA),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isActive ? color : Color(0xFFE9ECEF),
                    width: 2,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: isActive ? color : Color(0xFF6C757D),
                ),
              ),
              
              SizedBox(height: 12),
              
              Text(
                valveName,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2C3E50),
                ),
                textAlign: TextAlign.center,
              ),
              
              SizedBox(height: 8),
              
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive 
                      ? color.withOpacity(0.1)
                      : Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isActive ? color : Color(0xFFDEE2E6),
                  ),
                ),
                child: Text(
                  isActive ? 'OPEN' : 'CLOSED',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isActive ? color : Color(0xFF6C757D),
                  ),
                ),
              ),
              
              SizedBox(height: 12),
              
              Switch(
                value: isActive,
                onChanged: (_) => onToggle(),
                activeColor: color,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
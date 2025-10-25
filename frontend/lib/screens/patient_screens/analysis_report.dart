import 'package:flutter/material.dart';

// Enum to define chart types for the reusable widget
enum ChartType { line, bar }

class AnalysisReportScreen extends StatefulWidget {
  const AnalysisReportScreen({super.key});

  @override
  State<AnalysisReportScreen> createState() => _AnalysisReportScreenState();
}

class _AnalysisReportScreenState extends State<AnalysisReportScreen> {
  // Sample data for heart rate chart over 7 days
  final List<double> heartRateData = [75, 72, 78, 80, 76, 74, 79];
  final List<String> days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  // Sample data for blood pressure chart over 7 days
  final List<double> bloodPressureData = [120, 125, 118, 130, 122, 128, 124];
  final List<String> bloodPressureLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  // Sample data for diabetic chart: blood glucose levels over 6 months
  final List<double> diabeticData = [6.2, 5.8, 6.0, 6.5, 6.1, 5.9];
  final List<String> months = ['Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFDDF0F5),
      appBar: AppBar(
        title: const Text(
          'Health Analysis Report',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF18A3B6),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildReportHeader(),
              const SizedBox(height: 20),
              HealthChartCard(
                title: 'Heart Rate History',
                data: heartRateData,
                labels: days,
                chartType: ChartType.line,
                labelDescription: 'Last 7 days',
              ),
              const SizedBox(height: 20),
              HealthChartCard(
                title: 'Blood Pressure History',
                data: bloodPressureData,
                labels: bloodPressureLabels,
                chartType: ChartType.line,
                labelDescription: 'Last 7 days',
              ),
              const SizedBox(height: 20),
              HealthChartCard(
                title: 'Diabetic Report',
                data: diabeticData,
                labels: months,
                chartType: ChartType.bar,
                labelDescription: 'Last 6 months (HbA1c %)',
              ),
              const SizedBox(height: 20),
              _buildDownloadButton(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Report for Sarah',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF18A3B6),
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Generated on August 18, 2025',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildDownloadButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Downloading full report...'),
              backgroundColor: Color(0xFF32BACD),
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF18A3B6),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 5,
        ),
        child: const Text(
          'Download Full Report (PDF)',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

// Reusable Health Chart Card Widget
class HealthChartCard extends StatefulWidget {
  final String title;
  final List<double> data;
  final List<String> labels;
  final ChartType chartType;
  final String labelDescription;

  const HealthChartCard({
    Key? key,
    required this.title,
    required this.data,
    required this.labels,
    required this.chartType,
    required this.labelDescription,
  }) : super(key: key);

  @override
  _HealthChartCardState createState() => _HealthChartCardState();
}

class _HealthChartCardState extends State<HealthChartCard> {
  int? _tappedIndex;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF32BACD),
            ),
          ),
          const SizedBox(height: 10),
          AspectRatio(
            aspectRatio: 1.5,
            child: GestureDetector(
              onTapUp: (details) {
                final box = context.findRenderObject() as RenderBox;
                final localPosition = box.globalToLocal(details.globalPosition);
                final chartWidth = box.size.width - 50;
                final index = (localPosition.dx / (chartWidth / (widget.data.length - 1))).round();
                setState(() {
                  if (index >= 0 && index < widget.data.length) {
                    _tappedIndex = index;
                  }
                });
              },
              child: CustomPaint(
                painter: widget.chartType == ChartType.line
                    ? _LineChartPainter(
                        widget.data,
                        widget.labels,
                        _tappedIndex,
                      )
                    : _BarChartPainter(
                        widget.data,
                        widget.labels,
                        _tappedIndex,
                      ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              widget.labelDescription,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom Painter for the Line Chart
class _LineChartPainter extends CustomPainter {
  final List<double> data;
  final List<String> labels;
  final int? tappedIndex;

  _LineChartPainter(this.data, this.labels, this.tappedIndex);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final chartWidth = size.width;
    final chartHeight = size.height;
    final maxDataValue = data.reduce((a, b) => a > b ? a : b);
    final minDataValue = data.reduce((a, b) => a < b ? a : b);
    const padding = 20.0;
    const yAxisLabelWidth = 30.0;
    final chartAreaWidth = chartWidth - yAxisLabelWidth - padding;

    final linePaint = Paint()
      ..color = const Color(0xFF32BACD)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final pointPaint = Paint()
      ..color = const Color(0xFF18A3B6)
      ..style = PaintingStyle.fill;

    final highlightPaint = Paint()
      ..color = const Color(0xFF85CEDA)
      ..style = PaintingStyle.fill;

    // Draw Y-axis labels
    final yInterval = (maxDataValue - minDataValue) / 2;
    for (int i = 0; i <= 2; i++) {
      final yValue = minDataValue + i * yInterval;
      final yPosition = (1 - (yValue - minDataValue) / (maxDataValue - minDataValue)) * chartHeight;
      final textPainter = TextPainter(
        text: TextSpan(
          text: yValue.toInt().toString(),
          style: const TextStyle(color: Colors.grey, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout(minWidth: 0, maxWidth: yAxisLabelWidth);
      textPainter.paint(canvas, Offset(0, yPosition - textPainter.height / 2));
    }

    final path = Path();
    for (int i = 0; i < data.length; i++) {
      final xPosition = yAxisLabelWidth + (i / (data.length - 1)) * chartAreaWidth;
      final yPosition = (1 - (data[i] - minDataValue) / (maxDataValue - minDataValue)) * chartHeight;

      if (i == 0) {
        path.moveTo(xPosition, yPosition);
      } else {
        path.lineTo(xPosition, yPosition);
      }
      canvas.drawCircle(Offset(xPosition, yPosition), 5, pointPaint);

      final textPainter = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: const TextStyle(color: Colors.grey, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout(minWidth: 0, maxWidth: chartAreaWidth / data.length);
      textPainter.paint(canvas, Offset(xPosition - textPainter.width / 2, chartHeight + 5));

      if (i == tappedIndex) {
        canvas.drawCircle(Offset(xPosition, yPosition), 8, highlightPaint);
        final tooltipPainter = TextPainter(
          text: TextSpan(
            text: '${data[i]}',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        const tooltipPadding = 5.0;
        final tooltipRect = Rect.fromLTRB(
          xPosition - tooltipPainter.width / 2 - tooltipPadding,
          yPosition - tooltipPainter.height - 20,
          xPosition + tooltipPainter.width / 2 + tooltipPadding,
          yPosition - 20,
        );
        final tooltipPaint = Paint()..color = Colors.black.withOpacity(0.7);
        canvas.drawRRect(RRect.fromRectAndRadius(tooltipRect, const Radius.circular(5)), tooltipPaint);
        tooltipPainter.paint(canvas, Offset(xPosition - tooltipPainter.width / 2, yPosition - tooltipPainter.height - 15));
      }
    }
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

// Custom Painter for the Bar Chart
class _BarChartPainter extends CustomPainter {
  final List<double> data;
  final List<String> labels;
  final int? tappedIndex;

  _BarChartPainter(this.data, this.labels, this.tappedIndex);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final chartWidth = size.width;
    final chartHeight = size.height;
    final maxDataValue = data.reduce((a, b) => a > b ? a : b);
    const yAxisLabelWidth = 30.0;
    const padding = 20.0;
    final chartAreaWidth = chartWidth - yAxisLabelWidth - padding;
    final barWidth = (chartAreaWidth / data.length) * 0.7;
    const barSpacing = 10.0;

    final normalBarPaint = Paint()..color = const Color(0xFF32BACD);
    final riskBarPaint = Paint()..color = Colors.red;
    final highlightPaint = Paint()..color = const Color(0xFF18A3B6);

    for (int i = 0; i < data.length; i++) {
      final barHeight = (data.isNotEmpty && maxDataValue > 0)
          ? (data.elementAt(i) / maxDataValue) * chartHeight
          : 0.0;
      final xPosition = yAxisLabelWidth + i * (barWidth + barSpacing) + barSpacing / 2;
      final barRect = Rect.fromLTWH(
        xPosition,
        chartHeight - barHeight,
        barWidth,
        barHeight,
      );

      final currentBarPaint = i == tappedIndex
          ? highlightPaint
          : (data.elementAt(i) > 6.0 ? riskBarPaint : normalBarPaint);
      canvas.drawRRect(RRect.fromRectAndRadius(barRect, const Radius.circular(5)), currentBarPaint);

      final textPainter = TextPainter(
        text: TextSpan(
          text: labels.elementAt(i),
          style: const TextStyle(color: Colors.grey, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(xPosition + barWidth / 2 - textPainter.width / 2, chartHeight + 5));
    
      if (i == tappedIndex) {
        final tooltipPainter = TextPainter(
          text: TextSpan(
            text: '${data.elementAt(i).toStringAsFixed(1)} %',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        const tooltipPadding = 5.0;
        final tooltipRect = Rect.fromLTRB(
          xPosition - tooltipPainter.width / 2 - tooltipPadding,
          chartHeight - barHeight - tooltipPainter.height - 15,
          xPosition + barWidth + tooltipPainter.width / 2 + tooltipPadding,
          chartHeight - barHeight - 15,
        );
        final tooltipPaint = Paint()..color = Colors.black.withOpacity(0.7);
        canvas.drawRRect(RRect.fromRectAndRadius(tooltipRect, const Radius.circular(5)), tooltipPaint);
        tooltipPainter.paint(canvas, Offset(xPosition + barWidth / 2 - tooltipPainter.width / 2, chartHeight - barHeight - tooltipPainter.height - 10));
      }
    }
    
    const yAxisCount = 3;
    final yInterval = maxDataValue / (yAxisCount - 1);
    for(int i=0; i< yAxisCount; i++) {
        final yValue = maxDataValue - i * yInterval;
        final yPosition = (maxDataValue > 0) ? (yValue / maxDataValue) * chartHeight : 0.0;
        final textPainter = TextPainter(
          text: TextSpan(
            text: yValue.toStringAsFixed(1),
            style: const TextStyle(color: Colors.grey, fontSize: 10),
          ),
          textDirection: TextDirection.ltr,
        )..layout(minWidth: 0, maxWidth: yAxisLabelWidth);
        textPainter.paint(canvas, Offset(0, yPosition - textPainter.height/2));
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.tappedIndex != tappedIndex;
  }
}
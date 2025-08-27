import 'dart:ui';
import 'package:flutter/material.dart';

class AnalyticsHelpScreen extends StatefulWidget {
  const AnalyticsHelpScreen({super.key});

  @override
  State<AnalyticsHelpScreen> createState() => _AnalyticsHelpScreenState();
}

class _AnalyticsHelpScreenState extends State<AnalyticsHelpScreen> {
  final Map<String, bool> _expandedSections = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: AppBar(
              backgroundColor: const Color(0xFF1A1A1A).withOpacity(0.8),
              elevation: 0,
              toolbarHeight: 60,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: const Text(
                'Analytics & Labels Guide',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF1A1A1A),
              const Color(0xFF0F0F0F),
            ],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.only(top: 80, left: 16, right: 16, bottom: 24),
          children: [
            _buildIntroSection(),
            
            const SizedBox(height: 24),
            
            // Financial Analytics Section
            _buildHelpSection(
              'financial_analytics',
              'Financial Analytics Dashboard',
              Icons.analytics,
              [
                _buildHelpItem(
                  'Overview Tab',
                  'Get a complete picture of your financial health.',
                  'Shows your total income, expenses, net flow, and savings rate. The pie chart breaks down spending by category, while the quick stats widget provides key metrics at a glance.',
                ),
                _buildHelpItem(
                  'Trends Tab',
                  'Track your financial patterns over time.',
                  'View monthly income vs expenses trends with interactive line charts. Monitor your net cash flow and identify spending patterns. Growth indicators show how your finances are changing.',
                ),
                _buildHelpItem(
                  'Categories Tab',
                  'Understand where your money goes.',
                  'See detailed breakdown of all transaction categories with amounts, percentages, and transaction counts. Tap any category to see recent transactions and get more details.',
                ),
                _buildHelpItem(
                  'Flow Tab',
                  'Analyze your cash flow patterns.',
                  'Compare income vs expenses with bar charts, view top spending categories, and review key cash flow metrics including savings rate and average transaction amounts.',
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Time Periods Section
            _buildHelpSection(
              'time_periods',
              'Time Period Filters',
              Icons.date_range,
              [
                _buildHelpItem(
                  '1 Month',
                  'Recent financial activity and short-term trends.',
                  'Perfect for tracking recent spending habits and immediate financial changes. Useful for monthly budgeting and expense tracking.',
                ),
                _buildHelpItem(
                  '3 Months',
                  'Quarterly analysis and seasonal patterns.',
                  'Default view that provides a good balance of recent activity and trend analysis. Ideal for identifying spending patterns and financial habits.',
                ),
                _buildHelpItem(
                  '6 Months & 1 Year',
                  'Long-term trends and financial planning.',
                  'Great for understanding long-term financial health, identifying seasonal spending patterns, and making informed financial decisions.',
                ),
                _buildHelpItem(
                  'All Time',
                  'Complete financial history since wallet creation.',
                  'Shows your entire financial journey with the wallet. Useful for comprehensive analysis and understanding your overall financial patterns.',
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Address Labeling Section
            _buildHelpSection(
              'address_labeling',
              'Address Labeling System',
              Icons.label,
              [
                _buildHelpItem(
                  'Why Label Addresses?',
                  'Organize and track your financial activities.',
                  'Labels help you identify the purpose of each address, track income sources, monitor expenses, and maintain better financial organization. Essential for business use and tax reporting.',
                ),
                _buildHelpItem(
                  'Label Categories',
                  'Six main categories for comprehensive organization.',
                  '• Income Sources: Salary, business, solar income, investments\n• Expenses: Bills, shopping, food, transportation\n• Savings & Investment: Emergency funds, trading, staking\n• Trading & DeFi: Exchange activities, DeFi protocols\n• External Addresses: Friends, merchants, services\n• Other: Custom labels and miscellaneous addresses',
                ),
                _buildHelpItem(
                  'Creating Labels',
                  'Easy label creation with smart suggestions.',
                  'Tap the label icon next to any address to create a label. Choose from 15+ predefined types or create custom labels. The system suggests appropriate categories based on transaction patterns.',
                ),
                _buildHelpItem(
                  'Color Coding',
                  'Visual organization with custom colors.',
                  'Each label type has a default color, but you can customize colors for better visual organization. Colors appear throughout the app to help you quickly identify address purposes.',
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Address Monitoring Section
            _buildHelpSection(
              'address_monitoring',
              'Address Monitoring & Analytics',
              Icons.monitor,
              [
                _buildHelpItem(
                  'Monitoring Screen',
                  'Track performance of labeled addresses.',
                  'Access via the Analytics button in your address list. View all labeled addresses with their activity levels, transaction counts, and net flow amounts.',
                ),
                _buildHelpItem(
                  'Address Analytics',
                  'Detailed insights for each labeled address.',
                  'See income, expenses, and net flow for each address. View transaction history filtered by specific addresses. Track activity patterns and identify your most active addresses.',
                ),
                _buildHelpItem(
                  'External Address Suggestions',
                  'Smart suggestions for frequently used addresses.',
                  'The app automatically detects external addresses you transact with frequently and suggests appropriate labels. Access via the magic wand icon in address monitoring.',
                ),
                _buildHelpItem(
                  'Bulk Operations',
                  'Efficiently manage multiple address labels.',
                  'Select multiple suggested addresses and apply labels in bulk. Edit or delete multiple labels at once. Perfect for organizing large numbers of addresses quickly.',
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Export and Sharing Section
            _buildHelpSection(
              'export_sharing',
              'Export & Sharing Features',
              Icons.share,
              [
                _buildHelpItem(
                  'Analytics Summary',
                  'Quick overview for sharing or record-keeping.',
                  'Tap the share icon to copy a formatted summary of your financial analytics. Includes key metrics, top categories, and insights. Perfect for sharing with financial advisors.',
                ),
                _buildHelpItem(
                  'CSV Export',
                  'Detailed data for spreadsheet analysis.',
                  'Export category breakdowns and monthly data in CSV format. Import into Excel, Google Sheets, or other tools for advanced analysis and record-keeping.',
                ),
                _buildHelpItem(
                  'Detailed Reports',
                  'Comprehensive financial reports.',
                  'Generate detailed reports with executive summaries, growth analysis, category breakdowns, and monthly trends. Ideal for tax preparation and financial planning.',
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Tips and Best Practices Section
            _buildHelpSection(
              'tips_best_practices',
              'Tips & Best Practices',
              Icons.lightbulb,
              [
                _buildHelpItem(
                  'Start with High-Activity Addresses',
                  'Label your most frequently used addresses first.',
                  'Focus on addresses with the most transactions or highest amounts. These will have the biggest impact on your analytics and organization.',
                ),
                _buildHelpItem(
                  'Use Descriptive Names',
                  'Create meaningful labels that you\'ll remember.',
                  'Instead of "Address 1", use "Solar Panel Income" or "Grocery Shopping". Descriptive names make your analytics more useful and easier to understand.',
                ),
                _buildHelpItem(
                  'Regular Review',
                  'Check your analytics monthly for insights.',
                  'Set a monthly reminder to review your financial analytics. Look for spending trends, identify areas for improvement, and adjust your financial habits accordingly.',
                ),
                _buildHelpItem(
                  'External Address Management',
                  'Keep track of who you\'re transacting with.',
                  'Label external addresses like exchanges, friends, and merchants. This helps with transaction tracking and provides better context for your financial activities.',
                ),
                _buildHelpItem(
                  'Privacy Considerations',
                  'Balance organization with privacy needs.',
                  'Labels are stored locally on your device. Consider your privacy needs when labeling addresses, especially if sharing your device or exporting data.',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntroSection() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary.withOpacity(0.1),
            Theme.of(context).colorScheme.primary.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.analytics,
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Financial Analytics & Address Labels',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Transform your BitcoinZ wallet into a powerful financial management tool. Learn how to use analytics to understand your spending patterns, organize addresses with labels, and gain insights into your financial health.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpSection(String sectionId, String title, IconData icon, List<Widget> items) {
    final isExpanded = _expandedSections[sectionId] ?? false;
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF2A2A2A).withOpacity(0.4),
            const Color(0xFF1F1F1F).withOpacity(0.3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _expandedSections[sectionId] = !isExpanded;
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      icon,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            Container(
              width: double.infinity,
              height: 1,
              color: Colors.white.withOpacity(0.05),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: item,
                )).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHelpItem(String title, String summary, String details) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            summary,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.9),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            details,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

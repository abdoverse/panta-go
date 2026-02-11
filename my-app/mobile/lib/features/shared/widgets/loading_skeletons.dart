import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class LoadingSkeletons extends StatelessWidget {
  const LoadingSkeletons({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        children: List.generate(3, (index) => const _SkeletonCard()),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Shimmer.fromColors(
        baseColor: Colors.grey[200]!,
        highlightColor: Colors.grey[100]!,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(width: 120, height: 16, color: Colors.white),
                        const SizedBox(height: 8),
                        Container(width: 80, height: 16, color: Colors.white),
                        const SizedBox(height: 8),
                        Container(width: 150, height: 12, color: Colors.white),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(width: double.infinity, height: 40, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12))),
            ],
          ),
        ),
      ),
    );
  }
}

class MarketplaceSkeleton extends StatelessWidget {
  const MarketplaceSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
        return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        children: List.generate(2, (index) => const _MarketplaceSkeletonCard()),
      ),
    );
  }
}

class _MarketplaceSkeletonCard extends StatelessWidget {
  const _MarketplaceSkeletonCard();

   @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
       shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Shimmer.fromColors(
         baseColor: Colors.grey[200]!,
        highlightColor: Colors.grey[100]!,
        child: Column(
          children: [
            Container(height: 140, color: Colors.white),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                       Container(width: 150, height: 20, color: Colors.white),
                       Container(width: 60, height: 30, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15))),
                    ],
                   ),
                   const SizedBox(height: 12),
                   Container(width: double.infinity, height: 14, color: Colors.white),
                   const SizedBox(height: 6),
                   Container(width: 200, height: 14, color: Colors.white),
                   const SizedBox(height: 20),
                   Container(width: double.infinity, height: 48, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12))),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}




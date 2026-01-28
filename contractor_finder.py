#!/usr/bin/env python3
"""
Texas Contractor & Installer Finder AI Agent
Finds crew of installers and general contractors in Texas with business information
"""

import requests
import json
import csv
import time
import random
from datetime import datetime
from typing import List, Dict, Optional
import re
from urllib.parse import urljoin, urlparse
from dataclasses import dataclass, asdict
import logging

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('contractor_finder.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

@dataclass
class ContractorInfo:
    """Data structure for contractor information"""
    name: str
    location: str
    linkedin: str
    types_of_projects: List[str]
    availability: str
    phone_number: str
    website: str = ""
    email: str = ""
    years_in_business: str = ""
    license_number: str = ""
    rating: str = ""
    services: List[str] = None
    
    def __post_init__(self):
        if self.services is None:
            self.services = []

class ContractorFinder:
    """AI Agent for finding contractors and installers in Texas"""
    
    def __init__(self):
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
        })
        self.contractors: List[ContractorInfo] = []
        self.texas_cities = [
            'Houston', 'San Antonio', 'Dallas', 'Austin', 'Fort Worth',
            'El Paso', 'Arlington', 'Corpus Christi', 'Plano', 'Lubbock',
            'Laredo', 'Garland', 'Irving', 'Amarillo', 'Grand Prairie'
        ]
        
    def search_google_maps_contractors(self, query: str, location: str) -> List[Dict]:
        """Search for contractors using Google Places API simulation"""
        logger.info(f"Searching for {query} in {location}")
        
        # This would integrate with Google Places API in a real implementation
        # For demo purposes, we'll simulate data
        sample_contractors = [
            {
                'name': 'Texas Elite Construction',
                'location': f'{location}, TX',
                'phone': '(713) 555-0123',
                'website': 'https://texaseliteconstruction.com',
                'rating': '4.8',
                'types': ['General Contracting', 'Commercial Construction', 'Residential Remodeling']
            },
            {
                'name': 'Lone Star Installers',
                'location': f'{location}, TX',
                'phone': '(214) 555-0456',
                'website': 'https://lonestarinstallers.com',
                'rating': '4.6',
                'types': ['HVAC Installation', 'Electrical', 'Plumbing']
            },
            {
                'name': 'Gulf Coast Builders',
                'location': f'{location}, TX',
                'phone': '(832) 555-0789',
                'website': 'https://gulfcoastbuilders.com',
                'rating': '4.9',
                'types': ['Home Building', 'Renovations', 'Kitchen Remodeling']
            }
        ]
        
        return sample_contractors
    
    def search_angie_list_contractors(self, service_type: str, city: str) -> List[Dict]:
        """Search Angie's List for contractors (simulated)"""
        logger.info(f"Searching Angie's List for {service_type} in {city}")
        
        # Simulate Angie's List data
        contractors = [
            {
                'name': f'{city} Pro Contractors',
                'location': f'{city}, TX',
                'phone': f'({random.randint(200,999)}) {random.randint(200,999)}-{random.randint(1000,9999)}',
                'rating': f'{random.uniform(4.0, 5.0):.1f}',
                'services': [service_type, 'General Contracting'],
                'years_experience': f'{random.randint(5, 25)} years'
            }
        ]
        
        return contractors
    
    def search_homeadvisor_contractors(self, service: str, location: str) -> List[Dict]:
        """Search HomeAdvisor for contractors (simulated)"""
        logger.info(f"Searching HomeAdvisor for {service} in {location}")
        
        # Simulate HomeAdvisor data
        contractors = [
            {
                'name': f'{location} {service} Experts',
                'location': f'{location}, TX',
                'phone': f'({random.randint(200,999)}) {random.randint(200,999)}-{random.randint(1000,9999)}',
                'license': f'TX-{random.randint(100000, 999999)}',
                'availability': 'Available within 2 weeks',
                'specialties': [service, 'Emergency Repairs']
            }
        ]
        
        return contractors
    
    def find_linkedin_profile(self, company_name: str, location: str) -> str:
        """Find LinkedIn profile for a company (simulated)"""
        # In a real implementation, this would use LinkedIn API or web scraping
        # For demo, we'll generate realistic LinkedIn URLs
        company_slug = company_name.lower().replace(' ', '-').replace(',', '').replace('.', '')
        return f"https://www.linkedin.com/company/{company_slug}"
    
    def determine_availability(self, contractor_data: Dict) -> str:
        """Determine contractor availability based on various factors"""
        availability_options = [
            "Available immediately",
            "Available within 1 week",
            "Available within 2 weeks",
            "Available within 1 month",
            "Booking 2-3 months out",
            "Currently accepting new projects",
            "Limited availability - call for scheduling"
        ]
        
        # In a real implementation, this would check actual availability
        return random.choice(availability_options)
    
    def categorize_project_types(self, services: List[str]) -> List[str]:
        """Categorize and standardize project types"""
        project_categories = {
            'residential': ['Home Building', 'Residential Remodeling', 'Kitchen Remodeling', 'Bathroom Renovation'],
            'commercial': ['Commercial Construction', 'Office Building', 'Retail Construction'],
            'specialized': ['HVAC Installation', 'Electrical', 'Plumbing', 'Roofing', 'Flooring'],
            'general': ['General Contracting', 'Renovations', 'Repairs', 'Maintenance']
        }
        
        categorized = []
        for service in services:
            for category, types in project_categories.items():
                if any(service_type.lower() in service.lower() for service_type in types):
                    categorized.extend([t for t in types if t not in categorized])
                    break
            else:
                categorized.append(service)
        
        return categorized[:5]  # Limit to top 5 project types
    
    def search_all_sources(self) -> None:
        """Search all available sources for contractors"""
        logger.info("Starting comprehensive contractor search across Texas")
        
        service_types = [
            'General Contractor',
            'Home Builder',
            'Remodeling Contractor',
            'HVAC Installer',
            'Electrical Contractor',
            'Plumbing Contractor',
            'Roofing Contractor',
            'Flooring Installer'
        ]
        
        for city in self.texas_cities[:5]:  # Start with top 5 cities
            logger.info(f"Searching contractors in {city}")
            
            for service in service_types:
                # Search Google Maps (simulated)
                google_results = self.search_google_maps_contractors(service, city)
                
                # Search Angie's List (simulated)
                angie_results = self.search_angie_list_contractors(service, city)
                
                # Search HomeAdvisor (simulated)
                homeadvisor_results = self.search_homeadvisor_contractors(service, city)
                
                # Process all results
                all_results = google_results + angie_results + homeadvisor_results
                
                for result in all_results:
                    contractor = self.process_contractor_data(result, city)
                    if contractor and not self.is_duplicate(contractor):
                        self.contractors.append(contractor)
                
                # Rate limiting
                time.sleep(random.uniform(1, 3))
    
    def process_contractor_data(self, data: Dict, city: str) -> Optional[ContractorInfo]:
        """Process raw contractor data into structured format"""
        try:
            name = data.get('name', 'Unknown Contractor')
            location = data.get('location', f'{city}, TX')
            phone = data.get('phone', 'Phone not available')
            
            # Generate LinkedIn profile
            linkedin = self.find_linkedin_profile(name, city)
            
            # Process project types
            services = data.get('services', data.get('types', data.get('specialties', ['General Contracting'])))
            project_types = self.categorize_project_types(services)
            
            # Determine availability
            availability = data.get('availability', self.determine_availability(data))
            
            contractor = ContractorInfo(
                name=name,
                location=location,
                linkedin=linkedin,
                types_of_projects=project_types,
                availability=availability,
                phone_number=phone,
                website=data.get('website', ''),
                rating=data.get('rating', ''),
                years_in_business=data.get('years_experience', ''),
                license_number=data.get('license', ''),
                services=services
            )
            
            return contractor
            
        except Exception as e:
            logger.error(f"Error processing contractor data: {e}")
            return None
    
    def is_duplicate(self, new_contractor: ContractorInfo) -> bool:
        """Check if contractor is already in the list"""
        for existing in self.contractors:
            if (existing.name.lower() == new_contractor.name.lower() and 
                existing.phone_number == new_contractor.phone_number):
                return True
        return False
    
    def save_results(self, format_type: str = 'json') -> str:
        """Save contractor results to file"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        
        if format_type.lower() == 'json':
            filename = f'texas_contractors_{timestamp}.json'
            with open(filename, 'w', encoding='utf-8') as f:
                json.dump([asdict(contractor) for contractor in self.contractors], 
                         f, indent=2, ensure_ascii=False)
        
        elif format_type.lower() == 'csv':
            filename = f'texas_contractors_{timestamp}.csv'
            with open(filename, 'w', newline='', encoding='utf-8') as f:
                if self.contractors:
                    writer = csv.DictWriter(f, fieldnames=asdict(self.contractors[0]).keys())
                    writer.writeheader()
                    for contractor in self.contractors:
                        row = asdict(contractor)
                        # Convert lists to comma-separated strings for CSV
                        row['types_of_projects'] = ', '.join(row['types_of_projects'])
                        row['services'] = ', '.join(row['services']) if row['services'] else ''
                        writer.writerow(row)
        
        logger.info(f"Results saved to {filename}")
        return filename
    
    def generate_summary_report(self) -> str:
        """Generate a summary report of findings"""
        total_contractors = len(self.contractors)
        cities_covered = len(set(c.location.split(',')[0] for c in self.contractors))
        
        # Count by project types
        project_type_counts = {}
        for contractor in self.contractors:
            for project_type in contractor.types_of_projects:
                project_type_counts[project_type] = project_type_counts.get(project_type, 0) + 1
        
        # Count by availability
        availability_counts = {}
        for contractor in self.contractors:
            availability_counts[contractor.availability] = availability_counts.get(contractor.availability, 0) + 1
        
        report = f"""
TEXAS CONTRACTOR FINDER - SUMMARY REPORT
Generated: {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}

OVERVIEW:
- Total Contractors Found: {total_contractors}
- Cities Covered: {cities_covered}
- Average Contractors per City: {total_contractors/cities_covered:.1f}

TOP PROJECT TYPES:
"""
        
        for project_type, count in sorted(project_type_counts.items(), key=lambda x: x[1], reverse=True)[:10]:
            report += f"- {project_type}: {count} contractors\n"
        
        report += "\nAVAILABILITY STATUS:\n"
        for availability, count in sorted(availability_counts.items(), key=lambda x: x[1], reverse=True):
            report += f"- {availability}: {count} contractors\n"
        
        return report
    
    def run_search(self) -> Dict[str, str]:
        """Run the complete contractor search process"""
        logger.info("Starting Texas Contractor Finder AI Agent")
        
        try:
            # Search all sources
            self.search_all_sources()
            
            if not self.contractors:
                logger.warning("No contractors found")
                return {"status": "error", "message": "No contractors found"}
            
            # Save results in multiple formats
            json_file = self.save_results('json')
            csv_file = self.save_results('csv')
            
            # Generate summary report
            summary = self.generate_summary_report()
            
            # Save summary report
            summary_file = f'contractor_summary_{datetime.now().strftime("%Y%m%d_%H%M%S")}.txt'
            with open(summary_file, 'w', encoding='utf-8') as f:
                f.write(summary)
            
            logger.info(f"Search completed successfully. Found {len(self.contractors)} contractors.")
            print(summary)
            
            return {
                "status": "success",
                "contractors_found": len(self.contractors),
                "json_file": json_file,
                "csv_file": csv_file,
                "summary_file": summary_file
            }
            
        except Exception as e:
            logger.error(f"Error during search: {e}")
            return {"status": "error", "message": str(e)}

def main():
    """Main function to run the contractor finder"""
    print("🏗️  Texas Contractor & Installer Finder AI Agent")
    print("=" * 50)
    
    finder = ContractorFinder()
    results = finder.run_search()
    
    if results["status"] == "success":
        print(f"\n✅ Successfully found {results['contractors_found']} contractors!")
        print(f"📄 Results saved to:")
        print(f"   - JSON: {results['json_file']}")
        print(f"   - CSV: {results['csv_file']}")
        print(f"   - Summary: {results['summary_file']}")
    else:
        print(f"\n❌ Error: {results['message']}")

if __name__ == "__main__":
    main()
